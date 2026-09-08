function Resolve-LogPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Root
    )

    if ($Root -and -not ([IO.Path]::IsPathRooted($Path) -or $Path.Contains([IO.Path]::DirectorySeparatorChar) -or $Path.Contains('/'))) {
        $Path = Join-Path -Path $Root -ChildPath $Path
    }

    return Get-DatedLogPath -BasePath $Path
}
