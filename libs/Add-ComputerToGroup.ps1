function Add-ComputerToGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)][string]$GroupDn,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$MemberDns
    )

    $computerDn = $Computer.DistinguishedName

    if ($MemberDns.Contains($computerDn)) {
        return 'AlreadyMember'
    }

    Add-ADGroupMember -Identity $GroupDn -Members $computerDn -ErrorAction Stop
    [void]$MemberDns.Add($computerDn)

    return 'Added'
}
