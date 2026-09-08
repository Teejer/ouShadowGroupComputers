function Save-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$CurrentOuIndex,
        [string[]]$ProcessedDistinguishedNames = @(),
        [string[]]$FailedDistinguishedNames = @()
    )

    $state = [ordered]@{
        LastRunUtc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        CurrentOuIndex = $CurrentOuIndex
        ProcessedDistinguishedNames   = @($ProcessedDistinguishedNames)
        FailedDistinguishedNames      = @($FailedDistinguishedNames)
    }

    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}
