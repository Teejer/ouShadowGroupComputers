function Write-ErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)][string]$GroupName,
        [Parameter(Mandatory)][string]$GroupDistinguishedName,
        [Parameter(Mandatory)]$ErrorRecord
    )

    $invocation = $ErrorRecord.InvocationInfo
    $location = if ($invocation) { '{0}:{1}' -f $invocation.ScriptName, $invocation.ScriptLineNumber } else { '' }

    $record = [pscustomobject]@{
        TimeStamp    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        GroupName    = $GroupName
        GroupDistinguishedName      = $GroupDistinguishedName
        ComputerName = $Computer.Name
        ComputerDistinguishedName   = $Computer.DistinguishedName
        ErrorMessage = $ErrorRecord.Exception.Message
        ErrorId      = $ErrorRecord.FullyQualifiedErrorId
        ErrorAt      = $location
    }

    if (Test-Path -Path $Path) {
        $record | Export-Csv -Path $Path -NoTypeInformation -Append -Encoding UTF8
    } else {
        $record | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
}
