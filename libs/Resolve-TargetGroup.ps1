function Resolve-TargetGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GroupName,
        [string]$LogPath
    )

    try {
        return Get-ADGroup -Identity $GroupName -Properties Member -ErrorAction Stop
    } catch {
        Write-Log -Message "Could not find group '$GroupName': $($_.Exception.Message)" -Level ERROR -LogPath $LogPath
        return $null
    }
}
