function Add-NextComputer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)]$Group,
        [Parameter(Mandatory)][string]$GroupDn,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$MemberDns,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$ProcessedDns,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$FailedDns,
        [Parameter(Mandatory)][string]$AddLogPath,
        [Parameter(Mandatory)][string]$ErrorLogPath,
        [string]$LogPath,
        [int]$AddedSoFar = 0,
        [int]$BatchSize = 1
    )

    $computerDn = $Computer.DistinguishedName

    try {
        $result = Add-ComputerToGroup -Computer $Computer -GroupDn $GroupDn -MemberDns $MemberDns
        [void]$ProcessedDns.Add($computerDn)
        if ($result -eq 'Added') {
            Write-AddLog -Path $AddLogPath -Computer $Computer -GroupName $Group.Name -GroupDn $GroupDn
            Write-Log -Message "Added $computerDn ($($AddedSoFar + 1)/$BatchSize)" -LogPath $LogPath
            return 'Added'
        }

        Write-Log -Message "Already a member, skipping without counting toward batch: $computerDn" -LogPath $LogPath
        return 'AlreadyMember'
    } catch {
        [void]$FailedDns.Add($computerDn)
        Write-ErrorLog -Path $ErrorLogPath -Computer $Computer -GroupName $Group.Name -GroupDn $GroupDn -ErrorRecord $_
        Write-Log -Message "Failed to add $computerDn : $($_.Exception.Message)" -Level ERROR -LogPath $LogPath
        return 'Failed'
    }
}
