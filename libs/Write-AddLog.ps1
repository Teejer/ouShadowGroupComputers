function Write-AddLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)][string]$GroupName,
        [Parameter(Mandatory)][string]$GroupDistinguishedName
    )

    $record = [pscustomobject]@{
        TimeStamp    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        GroupName    = $GroupName
        GroupDistinguishedName      = $GroupDistinguishedName
        ComputerName = $Computer.Name
        ComputerDistinguishedName   = $Computer.DistinguishedName
    }

    if (Test-Path -Path $Path) {
        $record | Export-Csv -Path $Path -NoTypeInformation -Append -Encoding UTF8
    } else {
        $record | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
}
