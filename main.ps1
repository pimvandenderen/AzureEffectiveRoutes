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
$exclsubscriptions = @("sub-onprem")

# Exclude VNETs that you don't want to check 
$exclvnets = @("myVNET")

# Exclude subnet's that you don't want to check (comma seperated)
$exclsubnets = @("AzureBastionSubnet")

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
    Get-AzSubscription -SubscriptionName $sub.Name | Set-AzContext
    $vnets = Get-AzVirtualNetwork | Where-Object {$exclvnets -notcontains $_.Name}

    foreach ($vnet in $vnets) { 
        $snets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet

        if (($snets.count -ne 0)) {
        # There are subnet's in the vnet, certain subnets are excluded.
            
            foreach ($snet in ($snets | Where-Object{$exclsubnets -notcontains $_.Name})) {

                # Check if there is a VM we can use for the effective routes. 
                foreach ($id in ($snet.IpConfigurations.ID | Where-Object {$_.NICID.count} -ne 0)) {
                    $vmnic = ParseAzNetworkInterfaceID -resourceID $id 
                    $vmnic = Get-AzNetworkInterface -Name $vmnic[2]
                
                    if (!($vmnic.VirtualMachine)) {
                        # No VM is attached to the NIC.
                        write-host "NIC is not for a virtual machine or it's not attached to a VM."

                    } else { 
                        # NIC has a VM attached, check the status of the VM. 
                        $vm = Get-AzVM -Name (($vmnic.VirtualMachine.Id.Split("/") | Select-Object -Last 1)) -Status
                
                        if ($vm.PowerState -eq "VM running") {

                            # This VM can be used to show the effective routes for this subnet
                            write-host "$($vm.Name) can be used for the effective routes for subnet $($snet.name)"
                            $nicroutes = Get-AzEffectiveRouteTable -ResourceGroupName $vm.ResourceGroupName -NetworkInterfaceName $vmnic.Name

                            # Check if there is a route table attached 
                            if (!$snet.RouteTable) {
                                $rtattached = "No"
                                $rtname = $null
                            } else { 
                                $rtattached = "Yes"
                                $rtname = ($snet.RouteTable.ID.Split("/") | Select-Object -Last 1)
                            }

                            # Check if BGP Propgation is enabled
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
                                $inetroutes = $inetroutes.AddressPrefix -join ", "
                                

                            } else { 
                                $internetaccess = "Disabled"
                                $inetroutes = $null
                            }

                            # Check for routes to the Virtual Network Gateway
                            if (($nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"}).count -ne 0) {
                                $gatewayroutes = "Enabled"
                                
                                #Print effective Virtual Network Gateway Routes
                                $vngroutes = $nicroutes | Where-Object {$_.NextHopType -eq "VirtualNetworkGateway" -and $_.State -eq "Active"} | Select-Object AddressPrefix
                                $vngroutes = $vngroutes.AddressPrefix -join ", " 

                            } else { 
                                $gatewayroutes = "Disabled"
                                $vngroutes = $null
                            }

                            # Break the foreach loop, we found the effective routes on this route table. 
                            break
                        } 
                    } 
                
                
                }

                $output = New-Object System.Object
                $output | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
                $output | Add-Member -MemberType NoteProperty -Name "vNet Name" -Value $vnet.Name
                $output | Add-Member -MemberType NoteProperty -Name "Subnet Name" -Value $snet.Name
                $output | Add-Member -MemberType NoteProperty -Name "RouteTable Attached" -Value $rtattached
                $output | Add-Member -MemberType NoteProperty -Name "RouteTable Name" -Value $rtname
                $output | Add-Member -MemberType NoteProperty -Name "BGP Propagatation" -Value $bgppropagation
                $output | Add-Member -MemberType NoteProperty -Name "Internet Routes" -Value $internetaccess
                $output | Add-Member -MemberType NoteProperty -Name "InternetAddress Prefix" -Value $inetroutes
                $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGateway Routes" -Value $gatewayroutes
                $output | Add-Member -MemberType NoteProperty -Name "VirtualNetworkGateway AddressPrefix" -Value $vngroutes
                $outputs.Add($output) | Out-Null

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
    $PSitem -replace "<td>No</td>", "<td style = 'background-color:#FF8080'>No</td>"
} | Out-File -FilePath "$filepath\AzureEffectiveRoutes.html"






