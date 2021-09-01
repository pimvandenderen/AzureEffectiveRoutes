# AzureEffectiveRoutes

## Introduction
Understanding routing in Azure can be challenging sometimes. I work with customers in regulated industries who want to inspect and control traffic 
on NVA's (Network Virtual appliances) such as Azure Firewall/Palo Alto to limit the egress points in Azure. To accomplish that, customers use a combination
of UDR's and BGP routes, however it is easy to overlook some. The goal of this script is to visualize all routing in Azure and highlight egress points (traffic going directly to the internet)

## How does it work
This script checks all the subscriptions in the Azure tenants for vNETs, subnet's and route tables attached to the subnets. For each subnet it will check if there is a virtual machine attached to the subnet that is up and running to get the effective routes for that subnet. At the moment, Azure doesn't support getting effective routes for a subnet / NIC without a running virtual machine.

## Variables
By default, this script checks all the subscriptions, VNET's and subnet's. You can exclude subscriptions, vNETs and subnets under the variable section in the script. I recommend to leave the "AzureBastionSubnet" in there since it's currently not supported to have UDR's on the AzureBastionSubnet (https://docs.microsoft.com/en-us/azure/bastion/bastion-faq). If you want to add subnet's, please make sure you comma seperate them, for example: @("AzureBastionSubnet", "MyOtherSubnet")

Note: This works in a "top down" approach. For example: If you exclude a subscription, you don't have to exclude the VNETs and subnet's within the subscription.

$exclsubscriptions <br>
Required: _No_ <br>
Add the full name of the subscription(s) that you want to exclude. 

$exclvnets <br>
Required: _No_ <br>
Add the full name of the VNET(s) that you want to exclude

$exclsubnets <br>
Required: _No_ <br>
Add the full name of the subnet(s) that you want to exclude. 

$filepath <br>
Required: _**Yes**_ <br>
The path where you want to store the outputted HTML file. 

## Example 
![AzureEffectiveRoutes] (/Images/AzureEffectiveRoutes.png)
