# AzureEffectiveRoutes

## Introduction
Understanding routing in Azure can be challenging sometimes. I work with customers in regulated industries who want to inspect and control traffic 
on NVA's (Network Virtual appliances) such as Azure Firewall/Palo Alto to limit the egress points in Azure. To accomplish that, customers use a combination
of UDR's and BGP routes, however it is easy to overlook some. The goal of this script is to visualize all routing in Azure and highlight egress points (traffic going directly to the internet)