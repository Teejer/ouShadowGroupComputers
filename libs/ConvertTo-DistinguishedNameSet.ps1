function ConvertTo-DistinguishedNameSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object[]]$DistinguishedNames
    )

    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($distinguishedName in $DistinguishedNames) {
        if ($distinguishedName) { [void]$set.Add([string]$distinguishedName) }
    }
    return ,$set
}
