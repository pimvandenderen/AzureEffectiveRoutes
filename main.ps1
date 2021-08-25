#Import modules
Import-Module C:\Users\pvandenderen\Documents\WindowsPowerShell\Modules\Az.Accounts
Import-Module C:\Users\pvandenderen\Documents\WindowsPowerShell\Modules\Az.Network
Import-Module C:\Users\pvandenderen\Documents\WindowsPowerShell\Modules\Az.Compute

# Variables
$exclsubnets = @("AzureBastionSubnet", "AzureFirewallSubnet")

# Connect to Azure
Connect-AzAccount

#Functions
function ParseAzNetworkInterfaceID {
    param (
       [string]$resourceID
   )
   $array = $resourceID.Split('/') 
   $indexG = 0..($array.Length -1) | Where-Object {$array[$_] -eq 'subscriptions'}
   $indexV = 0..($array.Length -1) | Where-Object {$array[$_] -eq 'resourceGroups'}
   $indexX = 0..($array.Length -1) | Where-Object {$array[$_] -eq 'networkInterfaces'}
   $result = $array.get($indexG+1),$array.get($indexV+1),$array.get($indexX+1)
   return $result
}
function CheckPrivateIPaddress {
    param (
        [string]$IPaddress
    )
    $IPaddress -match '^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\..*'
    return $result
}


$rts = New-Object System.Collections.ArrayList
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) { 
    Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext
    
    $vnets = Get-AzVirtualNetwork

    foreach ($vnet in $vnets) { 
        $snets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet

        if (($snets.count -ne 0)) {
        # There are subnet's in the vnet, certain subnets are excluded.
            
            foreach ($snet in ($snets | Where-Object{$exclsubnets -notcontains $_.Name})) {
                
                if ($snet.RouteTable.count -eq 0) {

                    # There is no route table attached. 
                    Write-host "Subnet "$snet.Name" has no route table attached"
                    write-host "Assuming a default route to the internet "
                    $rtname = ""
                    
                } else {

                    # There is a route table attached. 
                    $rtname = (($snet.RouteTable.ID).Split("/"))[-1]
                    Write-Host "Subnet "$snet.Name" has a route table attached. Route table name is $rtname in subscription "$sub.Name""

                    # Since there is a route table attached, check if there is a VM we can use for the effective routes. 
                    foreach ($id in ($snet.IpConfigurations.ID | Where-Object {$_.NICID.count} -ne 0)) {
                        $vmnic = ParseAzNetworkInterfaceID -resourceID $id 
                        $vmnic = Get-AzNetworkInterface -Name $vmnic[2]
                    
                        if (!($vmnic.VirtualMachine)) {
                            # No VM is attached to the NIC.
                            write-host "No VM is attached to NIC: $($vmnic.Name)"   
                        } else { 
                            # NIC has a VM attached, check the status of the VM. 
                            $vm = Get-AzVM -Name (($vmnic.VirtualMachine.Id.Split("/") | Select-Object -Last 1)) -Status
                    
                            if ($vm.PowerState -eq "VM running") {

                                # This VM can be used to show the effective routes for this subnet, break the foreach loop
                                write-host "$($vm.Name) can be used for the effective routes for subnet $($snet.name)"

                                # Break the foreach loop, we found the effective routes on this route table. 
                                break
                            } 
                        } 
                    
                    
                    }


                }

                $rt = New-Object System.Object
                $rt | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $sub.Id
                $rt | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $sub.Name
                $rt | Add-Member -MemberType NoteProperty -Name "vNetID" -Value $vnet.Id
                $rt | Add-Member -MemberType NoteProperty -Name "vNetName" -Value $vnet.Name
                $rt | Add-Member -MemberType NoteProperty -Name "SubnetID" -Value $snet.Id
                $rt | Add-Member -MemberType NoteProperty -Name "SubnetName" -Value $snet.Name
                $rt | Add-Member -MemberType NoteProperty -Name "RouteTableName" -Value $rtname
                $rt | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
                $rt | Add-Member -MemberType NoteProperty -Name "VMNicID" -Value $vmnic.Id
                $rts.Add($rt) | Out-Null

                $vmnic = $null
                $vm = $null

            }
            
        } else {
            # No subnet's are found    
            write-host "No subnets in VNET "$vnet.Name" are found" 
        }


    }


}

# If a VM is found, we can look at the effective routes.
#$vms = $rts | Where-Object {$_.VMName -ne $null}
$outputs = New-Object System.Collections.ArrayList

foreach ($vm in $rts) {

    if ($vm.RouteTableName -eq "") { 
        # No Route table is associated to the subnet. 
        $rtattached = "No"
    }

    $nicinfo = ParseAzNetworkInterfaceID -resourceID $vm.VmNicID
    $nicroutes = Get-AzEffectiveRouteTable -ResourceGroupName $nicinfo[1] -NetworkInterfaceName $nicinfo[2]
                                    
    # Check if BGP Propgation is enabled on the route table
    if ($nicroutes[0].DisableBgpRoutePropagation -eq "True") {
        $bgppropagation = "Disabled"
    } else {
        $bgppropagation = "Enabled"
    }

    # Check if internet access is overwritten
    if (($nicroutes | Where-Object {$_.NextHopType -eq "Internet" -and $_.State -eq "Active"}).count -ne 0) {
        $internetaccess = "Enabled"
        
        # Print effective internet routes
        $inetroutes = $nicroutes | Where-Object {$_.NextHopType -eq "Internet" -and $_.State -eq "Active"} | Select-Object AddressPrefix

    } else { 
        $internetaccess = "Disabled"
        $inetroutes.AddressPrefix = ""
    }

    # Check for routes to the Virtual Network Gateway
    if (($nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"}).count -ne 0) {
        $gatewayroutes = "Enabled"
        
        #Print effective Virtual Network Gateway Routes
        $vngroutes = $nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"} | Select-Object AddressPrefix
    } else { 
        $gatewayroutes = "Disabled"
        $vngroutes.AddressPrefix = ""
    }

    $output = New-Object System.Object
    #$output | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $sub.Id
    $output | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $sub.Name
    #$output | Add-Member -MemberType NoteProperty -Name "vNetID" -Value $vnet.Id
    $output | Add-Member -MemberType NoteProperty -Name "vNetName" -Value $vnet.Name
    #$rt | Add-Member -MemberType NoteProperty -Name "SubnetID" -Value $snet.Id
    $output | Add-Member -MemberType NoteProperty -Name "SubnetName" -Value $snet.Name
    $output | Add-Member -MemberType NoteProperty -Name "RouteTableAttached" -Value $rtattached
    $output | Add-Member -MemberType NoteProperty -Name "RouteTableName" -Value $rtname
    #$rt | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
    $output | Add-Member -MemberType NoteProperty -Name "BGP Properation" -Value $bgppropagation
    $output | Add-Member -MemberType NoteProperty -Name "InternetRoutes" -Value $internetaccess
    $output | Add-Member -MemberType NoteProperty -Name "InternetAddressPrefix" -Value $inetroutes.AddressPrefix
    $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGatewayRoutes" -Value $gatewayroutes
    $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGatewayAddressPrefix" -Value $vngroutes.AddressPrefix
    $outputs.Add($output) | Out-Null
    write-host $output
}

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@


$outputs | ConvertTo-Html -Head $Header | Out-File -FilePath C:\PvD\Git\AzureEffectiveRoutes\test.html






