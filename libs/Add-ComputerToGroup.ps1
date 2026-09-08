function Add-ComputerToGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)][string]$GroupDistinguishedName,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$MemberDistinguishedNames
    )

    $computerDistinguishedName = $Computer.DistinguishedName

    if ($MemberDistinguishedNames.Contains($computerDistinguishedName)) {
        return 'AlreadyMember'
    }

    Add-ADGroupMember -Identity $GroupDistinguishedName -Members $computerDistinguishedName -ErrorAction Stop
    [void]$MemberDistinguishedNames.Add($computerDistinguishedName)

    return 'Added'
}
