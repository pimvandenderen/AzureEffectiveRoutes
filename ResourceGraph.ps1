# Install the Resource Graph module from PowerShell Gallery
Install-Module -Name Az.ResourceGraph

$graphquery = "Resources
| where type =~ 'microsoft.network/networkinterfaces' 
| where isnotempty(properties.virtualMachine)
| project id, ipConfigurations = properties.ipConfigurations
| mvexpand ipConfigurations
| project id, subnetId = tostring(ipConfigurations.properties.subnet.id)
| parse kind=regex subnetId with '/virtualNetworks/' virtualNetwork '/subnets/' subnet 
| project id, virtualNetwork, subnet"



$output = Search-AzGraph $graphquery