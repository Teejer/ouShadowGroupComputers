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

# $PSScriptRoot is empty when the script is dot-sourced or piped into the
# shell (e.g. iwr | iex, or some schedulers), so fall back to the command
# path and finally to the current directory.
$scriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($PSCommandPath) {
    Split-Path -Path $PSCommandPath -Parent
} else {
    (Get-Location).ProviderPath
}

if (-not $CsvPath) {
    $CsvPath = Join-Path -Path $scriptRoot -ChildPath 'ous.csv'
}
if (-not $StatePath) {
    $StatePath = Join-Path -Path $scriptRoot -ChildPath 'state.json'
}

$libsPath = Join-Path $scriptRoot 'libs'
. (Join-Path $libsPath 'Write-Log.ps1')
. (Join-Path $libsPath 'Get-OuListFromCsv.ps1')
. (Join-Path $libsPath 'Get-ScriptState.ps1')
. (Join-Path $libsPath 'Save-ScriptState.ps1')
. (Join-Path $libsPath 'Get-NextComputers.ps1')
. (Join-Path $libsPath 'Add-ComputerToGroup.ps1')
. (Join-Path $libsPath 'Write-AddLog.ps1')
. (Join-Path $libsPath 'Write-ErrorLog.ps1')
. (Join-Path $libsPath 'Get-DatedLogPath.ps1')
. (Join-Path $libsPath 'Resolve-LogPath.ps1')
. (Join-Path $libsPath 'ConvertTo-DnsSet.ps1')
. (Join-Path $libsPath 'Reset-ScriptState.ps1')
. (Join-Path $libsPath 'Resolve-TargetGroup.ps1')
. (Join-Path $libsPath 'Add-NextComputer.ps1')

foreach ($logVar in @('LogPath', 'AddLogPath', 'ErrorLogPath')) {
    Set-Variable -Name $logVar -Value (Resolve-LogPath -Path (Get-Variable -Name $logVar -ValueOnly) -Root $scriptRoot)
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
$memberDnsCache = @{}
$processedDns = ConvertTo-DnsSet -Dns @($state.ProcessedDns)
$failedDns = ConvertTo-DnsSet -Dns @($state.FailedDns)

$added = 0
$loggedEntry = ''

while ($added -lt $BatchSize -and $state.CurrentOuIndex -lt $entries.Count) {
    $entry = $entries[$state.CurrentOuIndex]
    $entryLabel = "$($entry.OuDn) -> $($entry.GroupName)"

    if ($loggedEntry -ne $entryLabel) {
        Write-Log -Message "Processing $entryLabel" -LogPath $LogPath
        $loggedEntry = $entryLabel
    }

    if (-not $groupCache.ContainsKey($entry.GroupName)) {
        $resolved = Resolve-TargetGroup -GroupName $entry.GroupName -LogPath $LogPath
        $groupCache[$entry.GroupName] = $resolved
        if ($resolved) {
            $memberDnsCache[$resolved.DistinguishedName] = ConvertTo-DnsSet -Dns @($resolved.Member)
        }
    }

    $group = $groupCache[$entry.GroupName]
    if (-not $group) {
        Write-Log -Message "Skipping OU '$($entry.OuDn)': group '$($entry.GroupName)' could not be resolved." -Level ERROR -LogPath $LogPath
        $state.CurrentOuIndex++
        continue
    }

    $groupDn = $group.DistinguishedName
    $memberDns = $memberDnsCache[$groupDn]

    $excludeDns = @($processedDns) + @($failedDns)
    $candidates = @(Get-NextComputers -OuDn $entry.OuDn -SortBy $SortBy -ExcludeDns $excludeDns -IncludeSubOus:$IncludeSubOus)

    if ($candidates.Count -eq 0) {
        Write-Log -Message "Finished OU '$($entry.OuDn)'. Moving to next OU." -LogPath $LogPath
        $state.CurrentOuIndex++
        continue
    }

    $computer = $candidates[0]
    $outcome = Add-NextComputer -Computer $computer -Group $group -GroupDn $groupDn -MemberDns $memberDns -ProcessedDns $processedDns -FailedDns $failedDns -AddLogPath $AddLogPath -ErrorLogPath $ErrorLogPath -LogPath $LogPath -AddedSoFar $added -BatchSize $BatchSize
    if ($outcome -eq 'Added') {
        $added++
    }
}

Save-ScriptState -Path $StatePath -CurrentOuIndex $state.CurrentOuIndex -ProcessedDns @($processedDns) -FailedDns @($failedDns)

Write-Log -Message "Run finished. Added $added computer(s). OU progress: index $($state.CurrentOuIndex) of $($entries.Count)." -LogPath $LogPath

if ($state.CurrentOuIndex -ge $entries.Count) {
    Write-Log -Message 'All OUs in the list are now complete.' -LogPath $LogPath
}
