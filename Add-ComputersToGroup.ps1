[CmdletBinding()]
param(
    [string]$CsvPath,
    [string]$GroupName,
    [string]$StatePath,
    [string]$LogPath = 'Add-ComputersToGroup.log',
    [string]$AddLogPath = 'added-computers.log',
    [string]$ErrorLogPath = 'add-errors.log',
    [ValidateRange(1, 100)][int]$BatchSize = 5,
    [string]$SortBy = 'Name',
    [switch]$IncludeSubOus,
    [switch]$ResetState
)

$ErrorActionPreference = 'Stop'

# Capture the entry script's directory once, here at the top level, because
# inside dot-sourced functions $PSScriptRoot and $MyInvocation resolve to the
# lib file itself instead of the entry script. Falls back to the current
# directory when the script is piped in (e.g. iwr | iex).
$entryPath = $MyInvocation.MyCommand.Path
$scriptPath = if ($entryPath) {
    Split-Path -Parent $entryPath
} else {
    (Get-Location).ProviderPath
}

. (Join-Path $scriptPath 'libs/Import-Libs.ps1') -ScriptRoot $scriptPath

if (-not $CsvPath) {
    $CsvPath = Join-Path -Path $scriptPath -ChildPath 'ous.csv'
}
if (-not $StatePath) {
    $StatePath = Join-Path -Path $scriptPath -ChildPath 'state.json'
}

foreach ($logVar in @('LogPath', 'AddLogPath', 'ErrorLogPath')) {
    Set-Variable -Name $logVar -Value (Resolve-LogPath -Path (Get-Variable -Name $logVar -ValueOnly) -Root $scriptPath)
}

Import-Module ActiveDirectory

if ($ResetState) {
    Reset-ScriptState -StatePath $StatePath -LogPath $LogPath
}

Write-Log -Message '=== Run started ===' -LogPath $LogPath

$entries = Get-OuListFromCsv -Path $CsvPath

if ($GroupName) {
    foreach ($entry in $entries) {
        $entry.GroupName = $GroupName
    }
    Write-Log -Message "Loaded $($entries.Count) OU(s) from $CsvPath, all targeting override group '$GroupName'" -LogPath $LogPath
} else {
    Write-Log -Message "Loaded $($entries.Count) OU/group pair(s) from $CsvPath" -LogPath $LogPath
}

$state = Get-ScriptState -Path $StatePath

if ($state.CurrentOuIndex -ge $entries.Count) {
    Write-Log -Message 'All OUs in the list are complete. Use -ResetState to start over.' -LogPath $LogPath
    exit 0
}

$groupCache = @{}
$memberDistinguishedNamesCache = @{}
$processedDistinguishedNames = ConvertTo-DistinguishedNameSet -DistinguishedNames @($state.ProcessedDistinguishedNames)
$failedDistinguishedNames = ConvertTo-DistinguishedNameSet -DistinguishedNames @($state.FailedDistinguishedNames)

$added = 0
$loggedEntry = ''

while ($added -lt $BatchSize -and $state.CurrentOuIndex -lt $entries.Count) {
    $entry = $entries[$state.CurrentOuIndex]
    $entryLabel = "$($entry.OuDistinguishedName) -> $($entry.GroupName)"

    if ($loggedEntry -ne $entryLabel) {
        Write-Log -Message "Processing $entryLabel" -LogPath $LogPath
        $loggedEntry = $entryLabel
    }

    if (-not $groupCache.ContainsKey($entry.GroupName)) {
        $resolved = Resolve-TargetGroup -GroupName $entry.GroupName -LogPath $LogPath
        $groupCache[$entry.GroupName] = $resolved
        if ($resolved) {
            $memberDistinguishedNamesCache[$resolved.DistinguishedName] = ConvertTo-DistinguishedNameSet -DistinguishedNames @($resolved.Member)
        }
    }

    $group = $groupCache[$entry.GroupName]
    if (-not $group) {
        Write-Log -Message "Skipping OU '$($entry.OuDistinguishedName)': group '$($entry.GroupName)' could not be resolved." -Level ERROR -LogPath $LogPath
        $state.CurrentOuIndex++
        continue
    }

    $groupDistinguishedName = $group.DistinguishedName
    $memberDistinguishedNames = $memberDistinguishedNamesCache[$groupDistinguishedName]

    $excludeDistinguishedNames = @($processedDistinguishedNames) + @($failedDistinguishedNames)
    $candidates = @(Get-NextComputers -OuDistinguishedName $entry.OuDistinguishedName -SortBy $SortBy -ExcludeDistinguishedNames $excludeDistinguishedNames -IncludeSubOus:$IncludeSubOus)

    if ($candidates.Count -eq 0) {
        Write-Log -Message "Finished OU '$($entry.OuDistinguishedName)'. Moving to next OU." -LogPath $LogPath
        $state.CurrentOuIndex++
        continue
    }

    $computer = $candidates[0]
    $outcome = Add-NextComputer -Computer $computer -Group $group -GroupDistinguishedName $groupDistinguishedName -MemberDistinguishedNames $memberDistinguishedNames -ProcessedDistinguishedNames $processedDistinguishedNames -FailedDistinguishedNames $failedDistinguishedNames -AddLogPath $AddLogPath -ErrorLogPath $ErrorLogPath -LogPath $LogPath
    if ($outcome -eq 'Added') {
        $added++
    }
}

Save-ScriptState -Path $StatePath -CurrentOuIndex $state.CurrentOuIndex -ProcessedDistinguishedNames @($processedDistinguishedNames) -FailedDistinguishedNames @($failedDistinguishedNames)

Write-Log -Message "Run finished. Added $added computer(s). OU progress: index $($state.CurrentOuIndex) of $($entries.Count)." -LogPath $LogPath

if ($state.CurrentOuIndex -ge $entries.Count) {
    Write-Log -Message 'All OUs in the list are now complete.' -LogPath $LogPath
}
