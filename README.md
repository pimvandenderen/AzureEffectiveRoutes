# AzureEffectiveRoutes

## Introduction
Understanding routing in Azure can be challenging sometimes. I work with customers in regulated industries who want to inspect and control traffic 
on NVA's (Network Virtual appliances) such as Azure Firewall/Palo Alto to limit the egress points in Azure. To accomplish that, customers use a combination
of UDR's and BGP routes, however it is easy to overlook some. The goal of this script is to visualize all routing in Azure and highlight egress points (traffic going directly to the internet)

## How does it work
This script checks all the subscriptions in the Azure tenants for vNETs, subnet's and route tables attached to the subnets. For each subnet it will check if there is a virtual machine attached to the subnet that is up and running to get the effective routes for that subnet. At the moment, Azure doesn't support getting effective routes for a subnet / NIC without a running virtual machine.


## Variables and parameters
By default, this script checks all the subscriptions, VNET's and subnet's. You can exclude subscriptions, vNETs and subnets under the variable section in the script. I recommend to leave the "AzureBastionSubnet" in there since it's currently not supported to have UDR's on the AzureBastionSubnet (https://docs.microsoft.com/en-us/azure/bastion/bastion-faq). If you want to add subnet's, please make sure you comma seperate them, for example: @("AzureBastionSubnet", "MyOtherSubnet")

Note: This works in a "top down" approach. For example: If you exclude a subscription, you don't have to exclude the VNETs and subnet's within the subscription.

$filepath <br>
Required: _**Yes**_ <br>
The path where you want to store the outputted HTML file. <br>
.\Get-AzureEffectiveTenantRoutes.ps1 -filepath "C:\Git\AzureEffectiveRoutes" <br>

$exclsubscriptions <br>
Required: _No_ <br>
Add the full name of the subscription(s) that you want to exclude. <br>
.\Get-AzureEffectiveTenantRoutes.ps1 -filepath "C:\Git\AzureEffectiveRoutes" -exclsubscriptions "app-sub" <br>

$exclvnets <br>
Required: _No_ <br>
Add the full name of the VNET(s) that you want to exclude <br>
.\Get-AzureEffectiveTenantRoutes.ps1 -filepath "C:\Git\AzureEffectiveRoutes" -exclvnets "app-vnet" <br>

$exclsubnets <br>
Required: _No_ <br>
Add the full name of the subnet(s) that you want to exclude. <br>
.\Get-AzureEffectiveTenantRoutes.ps1 -filepath "C:\Git\AzureEffectiveRoutes" -exclsubnets "app-snet" <br>

.EXAMPLE <br>
.\Get-AzureEffectiveTenantRoutes.ps1 -filepath "C:\Git\AzureEffectiveRoutes" -verbose <br>


## Example 
Below is an example of the HTML report that is generated by the script. 
<br><br>
![AzureEffectiveRoutes](/Images/AzureEffectiveRoutes.PNG)
<br> 
_SubscriptionName:_ The name of the subscription. <br>
_vNET Name:_ The name of the vNET. <br>
_Subnet Name:_ The name of the subnet within the vNET.<br>
_EffectiveRoutes:_ Can we get the effective routes for this subnet <br>
_RouteTable Attached:_ Is there a route table attached (yes/no).<br>
_RouteTable Name:_ The name of the route table that is attached. <br>
_BGP Propagation:_ The status of BGP Propagation of the route table. <br>
_Internet Routes:_ The routes on the route table that have a _Next Hop Type_ as Internet and are active. <br>
_InternetAddress Prefix:_ If there are active Internet routes, these are the active Internet routes.<br>
_VirtualNetworkGateway Routes:_ The routes on the route table that have a _Next Hop Type_ as Virtual Network Gateway and are active.<br>
_VirtualNetworkGateway AddressPrefix:_ If there are active Virtual Network Gateway routes, these are the active Virtual Network Gateway routes.<br>
_NetworkVirtualAppliance Routes:_ The routes on the route table that have a _Next Hop IP Address_ to a Virtual Appliance. <br>
_NetworkVirtualAppliance AddressPrefix:_ The address prefix of the virtual appliance route(s). <br>
_NetworkVirtualAppliance NextHopIP:_ The IP address of the next hop for the virtual appliance route(s)<br>

## Next Steps
Now you have the HTML report, it's time to interpert the report. 
* Are there any routes going directly to the internet that you didn't expect? 
* Are there any routes not going to the Network Virtual Appliance (NVA) that you want to? 
* Are there any routes not going / going to the Virtual Network Gateway? 
* Is BGP route properation enabled/disabled on Route Tables where you did/did not expect it to? 
<br>

## FAQ
**Q:** What does this script do? <br>
_A:_ This script checks all the subscriptions in the Azure tenants for vNETs, subnet's and route tables attached to the subnets. For each subnet it will check if there is a virtual machine attached to the subnet that is up and running to get the effective routes for that subnet.

**Q:** What does this script **not** do? <br>
_A:_ This script is only for informational purposes. It doesn't make any changes to existing routing or fix any issues that are discovered in the report. 

**Q:** What are the permissions required to run this script? <br>
_A:_ You need an account that can login to your Azure tenant and has read access to all the Azure subscriptions. Within the subscription, it needs to be able to list the virtual networks, subnet's, route tables, network interface cards and virtual machines (read access).

**Q:** I need more help understanding the report. <br>
_A:_ Please feel free to reach out to me on Linkedin at https://www.linkedin.com/in/pimvandenderen/ or on Twitter at https://twitter.com/pimmerd90 if you have additional questions. 

**Q:** How can I submit feedback? <br>
_A:_ I'd love to get some feedback, please open an issue on Github with a description of your finding or reach out to me directly. 