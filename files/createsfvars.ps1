$outputObj = @{
    "HostbaseUrl" = $env:citrix_storefront_HostbaseUrl
    "FarmServers" = $env:citrix_storefront_FarmServers
    "StoreVirtualPath" = $env:citrix_storefront_StoreVirtualPath
    "TransportType" = $env:citrix_storefront_TransportType
    "GatewayUrl" = $env:citrix_storefront_GatewayUrl
    "GatewaySTAUrls"= $env:citrix_storefront_GatewaySTAUrls
    "GatewayName" = $env:citrix_storefront_GatewayName
}
    
$outputObj | Export-Clixml "C:\Logs\sf-vars.xml" -Force