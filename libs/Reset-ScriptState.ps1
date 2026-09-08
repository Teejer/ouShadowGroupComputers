function Reset-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [string]$LogPath
    )

    if (-not (Test-Path -Path $StatePath)) {
        return
    }

    Remove-Item -Path $StatePath -Force
    Write-Log -Message 'State file removed. Progress reset.' -LogPath $LogPath
}
