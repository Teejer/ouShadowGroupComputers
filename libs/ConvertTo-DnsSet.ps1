function ConvertTo-DnsSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object[]]$Dns
    )

    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($dn in $Dns) {
        if ($dn) { [void]$set.Add([string]$dn) }
    }
    return ,$set
}
