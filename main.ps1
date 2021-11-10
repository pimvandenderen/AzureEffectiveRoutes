# Load the PowerShell Modules
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
function LoadModule ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
}

#Import modules
LoadModule "Az.Accounts"
LoadModule "Az.Network"
LoadModule "Az.Compute"


# Variables
#-------------------
# Exclude subscriptions that you don't want to check
$exclsubscriptions = @("")

# Exclude VNETs that you don't want to check 
$exclvnets = @("myVNET")

# Exclude subnet's that you don't want to check (comma seperated)
$exclsubnets = @("AzureBastionSubnet", "RouteServerSubnet")

# Path of the HTML file to output
$filepath = "C:\PvD\Git\AzureEffectiveRoutes"
#-------------------



# Connect to Azure
Connect-AzAccount

# Check if the output path exists
if (Test-Path $filepath) {
    if ($filepath -notmatch '\\$') { 
        $filepath += '\'
    }

} else { 
    Write-host "File path is not found, please make sure the path $($filepath) exists "
    Break
}


$outputs = New-Object System.Collections.ArrayList
$subscriptions = Get-AzSubscription

foreach ($sub in ($subscriptions | Where-Object{$exclsubscriptions -notcontains $_.Name})) { 
    Set-AzContext -SubscriptionId $sub.SubscriptionId
    $vnets = Get-AzVirtualNetwork | Where-Object {$exclvnets -notcontains $_.Name}

    foreach ($vnet in $vnets) { 
        
        $snets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet
        # Check if there are subnet's in the VNET
        if (($snets.count -ne 0)) {
            
            # Loop through all the subnets in the VNET, filter out excluded subnets
            $snets = $snets | Where-Object {$exclsubnets -notcontains $_.Name}

            foreach ($snet in $snets) {

                # Check if there is a VM we can use for the effective routes per subnet
                if (($snet.IpConfigurations.ID).count -ne 0) {

                    # Check if there is a route table attached 
                    if (!$snet.RouteTable) {
                        $rtattached = "rtno"
                    } else { 
                        $rtattached = "Yes"
                        $rtname = ($snet.RouteTable.ID.Split("/") | Select-Object -Last 1)
                    }
                    
                    # We found a NIC attached to the subnet
                    $vmnic = ParseAzNetworkInterfaceID -resourceID $snet.IpConfigurations.Id 
                    $vmnic = Get-AzNetworkInterface -Name $vmnic[2]
                
                    if (!($vmnic.VirtualMachine)) {

                        # No VM is attached to the NIC, break out of this loop
                        write-host "NIC is not for a virtual machine or it's not attached to a VM."
                        $effroutes = "effno"

                    } else { 

                        # NIC has a VM attached, check the status of the VM. 
                        $vm = Get-AzVM -Name (($vmnic.VirtualMachine.Id.Split("/") | Select-Object -Last 1)) -Status

                        if ($vm.PowerState -ne "VM running") { 
                            # This VM isn't Powered On, check the next VM. 
                            write-host "VM name: $($vm.Name) cannot be used since it's not Powered On"
                            $effroutes = "effno"

                        } else {

                            # This VM can be used to show the effective routes for this subnet
                            write-host "$($vm.Name) can be used for the effective routes for subnet $($snet.name)"
                            $nicroutes = Get-AzEffectiveRouteTable -ResourceGroupName $vm.ResourceGroupName -NetworkInterfaceName $vmnic.Name
                            $effroutes = "Yes"

                            # Check if BGP Propgation is enabled
                            if (($nicroutes | Where-Object {$_.DisableBgpRoutePropagation -eq "True"}).count -ne 0) {
                                $bgppropagation = "Disabled"
                            } else {
                                $bgppropagation = "Enabled"
                            }

                            # Check if internet access is overwritten
                            if (($nicroutes | Where-Object {$_.NextHopType -eq "Internet" -and $_.State -eq "Active"}).count -ne 0) {
                                $internetaccess = "Enabled"
                                
                                # Print effective internet routes
                                $inetroutes = $nicroutes | Where-Object {$_.NextHopType -eq "Internet" -and $_.State -eq "Active"} | Select-Object AddressPrefix
                                $inetroutes = $inetroutes.AddressPrefix -join ", "
                                

                            } else { 
                                $internetaccess = "Disabled"
                            }

                            # Check for routes to the Virtual Network Gateway
                            if (($nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"}).count -ne 0) {
                                $gatewayroutes = "Enabled"
                                
                                #Print effective Virtual Network Gateway Routes
                                $vngroutes = $nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"} | Select-Object AddressPrefix,NextHopIpAddress
                                $vngroutesaddprefix = $vngroutes.AddressPrefix -join ", " 
                                $vngroutesnexthop = $vngroutes.NextHopIpAddress | Select-Object -Unique

                            } else { 
                                $gatewayroutes = "Disabled"
                            }

                            # Check for routes to the Virtual Network Appliance
                            if (($nicroutes | Where-Object {$_.Name -ne $null -and $_.NextHopIpAddress -ne $null}).count -ne 0) {
                                $applianceroutes = "Enabled"

                                #Print effective Virtual Network Appliance routes
                                $nvaroutes = $nicroutes | Where-Object {$_.Name -ne $null -and $_.NextHopIpAddress -ne $null} | Select-Object AddressPrefix,NextHopIpAddress 
                                $nvaprefix = $nvaroutes.AddressPrefix -join ", "
                                $nvanexthop = $nvaroutes.NextHopIpAddress | Select-Object -Unique
                                $nvanexthop = $nvanexthop -join ", "


                            } else { 
                                $applianceroutes = "Disabled"
                            }
                        } 
                    } 
                
                
                

                $output = New-Object System.Object
                $output | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
                $output | Add-Member -MemberType NoteProperty -Name "vNet Name" -Value $vnet.Name
                $output | Add-Member -MemberType NoteProperty -Name "Subnet Name" -Value $snet.Name
                $output | Add-Member -MemberType NoteProperty -Name "EffectiveRoutes" -Value $effroutes
                $output | Add-Member -MemberType NoteProperty -Name "RouteTable Attached" -Value $rtattached
                $output | Add-Member -MemberType NoteProperty -Name "RouteTable Name" -Value $rtname
                $output | Add-Member -MemberType NoteProperty -Name "BGP Propagation" -Value $bgppropagation
                $output | Add-Member -MemberType NoteProperty -Name "Internet Routes" -Value $internetaccess
                $output | Add-Member -MemberType NoteProperty -Name "InternetAddress Prefix" -Value $inetroutes
                $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGateway Routes" -Value $gatewayroutes
                $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGateway AddressPrefix" -Value $vngroutesaddprefix
                $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGateway NextHopIP" -Value $vngroutesnexthop
                $output | Add-Member -MemberType NoteProperty -Name "NetworkVirtualAppliance Routes" -Value $applianceroutes
                $output | Add-Member -MemberType NoteProperty -Name "NetworkVirtualAppliance AddressPrefix" -Value $nvaprefix
                $output | Add-Member -MemberType NoteProperty -Name "NetworkVirtualAppliance NextHopIP" -Value $nvanexthop

                $outputs.Add($output) | Out-Null
                }

                # Set the variables to $null
                $rtname = $null
                $internetaccess = $null
                $inetroutes = $null
                $gatewayroutes = $null
                $vngroutes = $null
                $vngroutesaddprefix = $null
                $vngroutesnexthop = $null
                $nvaprefix = $null
                $nvanexthop = $null
                $applianceroutes = $null
                $rtattached = $null
                $bgppropagation = $null
                

            }
            
        } else {
            # No subnet's are found    
            write-host "No subnets in VNET "$vnet.Name" are found" 
        }


    }


}

# Create the styling for the HTML table
$Header = @"
<style>
TABLE {
    border-width: 1px; 
    border-style: solid;
    border-color: black;
    border-collapse: collapse;
}
TH {
    border-width: 1px; 
    padding: 3px; 
    border-style: solid; 
    border-color: black; 
    background-color: #6495ED;
}
TD {
    border-width: 1px; 
    padding: 3px; 
    border-style: solid; 
    border-color: black;
}
</style>
"@

$body = @"
<h1> Report Details </h1> 
<p> The report was run on $(get-date). </p>
<p> The report was run by $(whoami).</p>
<br>
"@

$outputs | ConvertTo-Html -Head $Header -body $body| ForEach-Object { 
    $PSitem -replace "<td>no</td>", "<td style = 'background-color:#FF8080'>No</td>"
} | Out-File -FilePath "$filepath\AzureEffectiveRoutes.html"






