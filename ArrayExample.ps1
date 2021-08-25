#Check if the default route is invalidated
#Bypassing Appliances; going to Virtual Gateway directly.  

# Check if there are any VM's attached to the route table
foreach ($nic in $rts) {

     
    if ($nic.NICID.count -ne 0) {
    # There is a NIC attached to the subnet / route table  

        #foreach ($id in $nic.NICID) {
            $vmnic = $id.Split("/")[-3]
            $vmnic = Get-AzNetworkInterface -Name $vmnic

            if (!$vmnic.VirtualMachine) {
            # NIC is attached to a VM, check status of the VM. 
                $vm = Get-AzVM -Name $vmnic.VirtualMachine
            }
        }
    } else {
    # There is no NIC attached to the subnet. 
    }
}

$ids = $rts | Where-Object {($_.NICID.count) -ne 0} 

#foreach ($id in $ids.NICID) {








        foreach ($nicid in $nic.NICID) {
            $vmnic = $nic.NICID.Split("/")[-3]
            write-host $vmnic
        }

}

        if ($nic.NICID.count -ne 0) {

            do {
            # There is a NIC attached to the subnet / route table

            $vmnic = Get-AzNetworkInterface -Name $vmnic

            if ($vmnic.VirtualMachine -ne "") {
                # NIC is attached to a VM, check status of the VM. 
                 $vm = Get-AzVM -Name $vmnic.VirtualMachine
            }

            }
        }


}



foreach ($id in ($rts | Where-Object {($_.NICID.count) -ne 0}).NICID) {
    $vmnic = $id.Split("/")[-3]
    $vmnic = Get-AzNetworkInterface -Name $vmnic

    if (!($vmnic.VirtualMachine)) {
        # No VM is attached to the NIC.
        write-host "No VM is attached to NIC: $($vmnic.Name)"   
    } else { 
        # NIC has a VM attached, check the status of the VM. 
        $vm = Get-AzVM -Name (($vmnic.VirtualMachine.Id.Split("/") | Select-Object -Last 1)) -Status

        if ($vm.PowerState -eq "VM running") {
            # This VM can be used to show the effective routes for this subnet, break the foreach loop
            write-host "$($vm.Name) can be used for the effective routes"
            $outvm = $vm.Name
            exit
        } 
    } 


}

write-host $outvm







$resourceID = '/subscriptions/00/resourcegroups/rg-test/providers/microsoft.compute/virtualmachines/vm-test'

parseGroupAndName -resourceID $resourceID


    <#
    if ($nicroutes.NextHopType -eq "Internet") {

        if ($nicroutes.State -eq "Active") {
            write-host "There is an active internet route for VM $($nic.VMName) on subnet $($nic.SubnetName) in vNET $($nic.vNetName). The route prefix is "
        } 
        if ($nicroutes.State -eq "Invalid") { 
            Write-host "Good job, there is no active internet route VM $($nic.VMName) on subnet $($nic.SubnetName) in vNET $($nic.vNetName)"
        }


    }
    #>

'172.16.10.10' -match 



$report = "<html>
<style>
{font-family: Arial; font-size: 13pt;}
TABLE{border: 1px solid black; border-collapse: collapse; font-size:13pt;}
TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
TD{border: 1px solid black; padding: 5px; }
</style>
<h2>Server Space Report</h2>
<table>
<tr>
<th>Volume</th>
<th>Total Space</th>
<th>Free Space</th>
<th>Percent Full</th>
</tr>
</table>
<tr>
"


Foreach ($nsg in $nsgs) {
    $nsgRules = $nsg.SecurityRules
    foreach ($nsgRule in $nsgRules) {
        $nsgRule | Select-Object Name,Description,Priority,
                                 @{n="SourceAddressPrefix";e={$_.SourceAddressPrefix -join ","}},
                                 @{n="SourcePortRange";e={$_.SourcePortRange -join ","}},
                                 @{n="DestinationAddressPrefix";e={$_.DestinationAddressPrefix -join ","}},
                                 @{n="DestinationPortRange";e={$_.DestinationPortRange -join ","}},
                                 Protocol,Access,Direction |
         Export-Csv "$exportPath\$($nsg.Name).csv" -NoTypeInformation -Encoding ASCII -Append
    }
}


# If a VM is found, we can look at the effective routes.
$vms = $rts | Where-Object {$_.VMName -ne $null}
$output = New-Object System.Collections.ArrayList



    $nicinfo = ParseAzNetworkInterfaceID -resourceID $vm.VmNicID
    $nicroutes = Get-AzEffectiveRouteTable -ResourceGroupName $nicinfo[1] -NetworkInterfaceName $nicinfo[2]
   
    $internet = ($nicroutes | Where-Object {$_.NextHopType -eq "Internet"})

    foreach ($route in $internet) {
        if (!$internet) {
            $internetaccess = "True"
        } else { 
            $internetaccess = "False"
        }
    }

    $output = New-Object System.Object
    $output | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $vm.SubscriptionName
    $output | Add-Member -MemberType NoteProperty -Name "vNETName" -Value $vm.vNetName
    $output | Add-Member -MemberType NoteProperty -Name "SubNetName" -Value $vm.SubnetName
    $output | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.VMName
    $output | Add-Member -MemberType NoteProperty -Name "InternetAccess" -Value $internetaccess
    $output | Export-Csv -path C:\Pvd\output.csv -NoTypeInformation -Encoding ASCII -Append
}