function Get-OuListFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "OU list CSV not found: $Path"
    }

    $rows = @(Import-Csv -Path $Path)

    if ($rows.Count -eq 0) {
        throw "No rows found in OU list CSV: $Path"
    }

    $columns = @($rows[0].PSObject.Properties | ForEach-Object { $_.Name })

    if ($columns.Count -lt 2) {
        throw "OU list CSV must have two columns (OU and target group), found: $($columns -join ', ')"
    }

    $ouColumn = $columns[0]
    $groupColumn = $columns[1]

    $entries = foreach ($row in $rows) {
        $ou = ([string]$row.$ouColumn).Trim()
        $group = ([string]$row.$groupColumn).Trim()
        if ([string]::IsNullOrWhiteSpace($ou)) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($group)) {
            throw "Row for OU '$ou' in $Path has no target group."
        }
        [pscustomobject]@{
            OuDistinguishedName      = $ou
            GroupName = $group
        }
    }

    if (-not @($entries).Count) {
        throw "No OU values found in column '$ouColumn' of $Path"
    }

    return @($entries)
}
