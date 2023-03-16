[Uri]$HostbaseUrl = $env:citrix_storefront_HostbaseUrl
[long]$SiteId = 1
[string]$Farmtype = "XenDesktop"
[string[]]$FarmServers = @($env:citrix_storefront_FarmServers)
[string]$StoreVirtualPath = $env:citrix_storefront_StoreVirtualPath
[bool]$LoadbalanceServers = $true
[int]$Port = 80
[int]$SSLRelayPort = 443
[string]$TransportType = $env:citrix_storefront_TransportType
[Uri]$GatewayUrl = $env:citrix_storefront_GatewayUrl
[string[]]$GatewaySTAUrls = @($env:citrix_storefront_GatewaySTAUrls)
[string]$GatewaySubnetIP
[string]$GatewayName = $env:citrix_storefront_GatewayName
[string]$LogFolder = $env:citrix_logfolder
$authenticationVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Auth"
$receiverVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Web"

Start-Transcript -Path "$LogFolder\transcript.txt"

# Convert Variables
$FarmServers = $FarmServers -split ","
$GatewaySTAUrls = $GatewaySTAUrls -split ","

Write-Host "HostbaseURL = " + $HostbaseUrl
Write-Host "SiteId = " + $SiteId
Write-Host "Farmtype = " + $Farmtype
Write-Host "FarmServers = " + $FarmServers
Write-Host "StoreVirtualPath = " + $StoreVirtualPath
Write-Host "LoadbalanceServers = " + $LoadbalanceServers
Write-Host "Port = " + $Port
Write-Host "SSLRelayPort = " + $SSLRelayPort
Write-Host "TransportType = " + $TransportType
Write-Host "GatewayUrl = " + $GatewayUrl
Write-Host "GatewaySTAUrls = " + $GatewaySTAUrls
Write-Host "GatewaySubnetIP = " + $GatewaySubnetIP
Write-Host "GatewayName = " + $GatewayName
Write-Host "LogFolder = " + $LogFolder

Set-StrictMode -Version 2.0

# Any failure is a terminating failure.
$ErrorActionPreference = 'Stop'
$ReportErrorShowStackTrace = $true
$ReportErrorShowInnerException = $true

# Import StoreFront modules. Required for versions of PowerShell earlier than 3.0 that do not support autoloading
Import-Module Citrix.StoreFront
Import-Module Citrix.StoreFront.Stores
Import-Module Citrix.StoreFront.Authentication
Import-Module Citrix.StoreFront.WebReceiver

# Determine if the deployment already exists
$existingDeployment = Get-STFDeployment

if(-not $existingDeployment)
{
    # Install the required StoreFront components
    Add-STFDeployment -HostBaseUrl $HostbaseUrl -SiteId $SiteId -Confirm:$false
}
elseif($existingDeployment.HostbaseUrl -eq $HostbaseUrl)
{
    # The deployment exists but it is configured to the desired hostbase url
    Write-Output "A deployment has already been created with the specified hostbase url on this server and will be used."
}
else
{
    Write-Error "A deployment has already been created on this server with a different host base url."
}

# Determine if the authentication service at the specified virtual path exists
$authentication = Get-STFAuthenticationService -VirtualPath $authenticationVirtualPath

if(-not $authentication)
{
    # Add an Authentication service using the IIS path of the Store appended with Auth
    $authentication = Add-STFAuthenticationService $authenticationVirtualPath
}
else
{
    Write-Output "An Authentication service already exists at the specified virtual path and will be used."
}

# Determine if the store service at the specified virtual path exists
$store = Get-STFStoreService -VirtualPath $StoreVirtualPath

if(-not $store)
{
    # Add a Store that uses the new Authentication service configured to publish resources from the supplied servers
    $store = Add-STFStoreService -VirtualPath $StoreVirtualPath -AuthenticationService $authentication -FarmName $Farmtype -FarmType $Farmtype -Servers $FarmServers -LoadBalance $LoadbalanceServers `
        -Port $Port -SSLRelayPort $SSLRelayPort -TransportType $TransportType
}
else
{
    Write-Output "A Store service already exists at the specified virtual path and will be used. Farm and servers will be appended to this store."
    # Get the number of farms configured in the store
    $farmCount = (Get-STFStoreFarmConfiguration $store).Farms.Count

    # Append the farm to the store with a unique name
    Add-STFStoreFarm -StoreService $store -FarmName "Controller$($farmCount + 1)" -FarmType $Farmtype -Servers $FarmServers -LoadBalance $LoadbalanceServers -Port $Port `
        -SSLRelayPort $SSLRelayPort -TransportType $TransportType
}

# Determine if the receiver service at the specified virtual path exists
$receiver = Get-STFWebReceiverService -VirtualPath $receiverVirtualPath

if(-not $receiver)
{
    # Add a Receiver for Web site so users can access the applications and desktops in the published in the Store
    $receiver = Add-STFWebReceiverService -VirtualPath $receiverVirtualPath -StoreService $store
}
else
{
    Write-Output "A Web Receiver service already exists at the specified virtual path and will be used."
}

# Determine if PNA is configured for the Store service
$storePnaSettings = Get-STFStorePna -StoreService $store

if(-not $storePnaSettings.PnaEnabled)
{
    # Enable XenApp services on the Store and make it the default for this server
    Enable-STFStorePna -StoreService $store -AllowUserPasswordChange -DefaultPnaService
}

Write-Host "Simple Deployment complete"

# Determine the Authentication and Receiver sites based on the Store
$store = Get-STFStoreService -VirtualPath $StoreVirtualPath
$authentication = Get-STFAuthenticationService -StoreService $store
$receiverForWeb = Get-STFWebReceiverService -StoreService $store

# Get the Web Receiver CitrixAGBasic and ExplicitForms authentication method from the supported protocols
# Included for demonstration purposes as the protocol name can be used directly if known
$receiverMethods = Get-STFWebReceiverAuthenticationMethodsAvailable | Where-Object { $_ -match "Explicit" -or $_ -match "CitrixAG" }

# Enable CitrixAGBasic in Receiver for Web (required for remote access)
Set-STFWebReceiverAuthenticationMethods -WebReceiverService $receiverForWeb -AuthenticationMethods $receiverMethods

# Get the CitrixAGBasic authentication method from the protocols installed.
# Included for demonstration purposes as the protocol name can be used directly if known
$citrixAGBasic = Get-STFAuthenticationProtocolsAvailable | Where-Object { $_ -match "CitrixAGBasic" }

# Enable CitrixAGBasic in the Authentication service (required for remote access)
Enable-STFAuthenticationServiceProtocol -AuthenticationService $authentication -Name $citrixAGBasic

# Add a new Gateway used to access the new Store remotely
Add-STFRoamingGateway -Name $GatewayName -LogonType Domain -Version Version10_0_69_4 -GatewayUrl $GatewayUrl -SecureTicketAuthorityUrls $GatewaySTAUrls

# Get the new Gateway from the configuration (Add-STFRoamingGateway will return the new Gateway if -PassThru is supplied as a parameter)
$gateway = Get-STFRoamingGateway -Name $GatewayName

# If the gateway subnet was provided then set it on the gateway object
if($GatewaySubnetIP)
{
    Set-STFRoamingGateway -Gateway $gateway -SubnetIPAddress $GatewaySubnetIP
}

# Register the Gateway with the new Store
Register-STFStoreGateway -Gateway $gateway -StoreService $store -DefaultGateway
Write-Host "Remote Access Deployment complete"

# Additional Configuration 
write-output "Starting customizations"
$Rfw = Get-STFWebReceiverService -SiteId $SiteId -VirtualPath "/Citrix/StoreWeb"
write-output "Enabling loopback for SSL offload"
Set-STFWebReceiverCommunication -WebReceiverService $Rfw -Loopback "OnUsingHttp"
write-output "Workspace actions"
Set-STFWebReceiverUserInterface -WebReceiverService $Rfw -WorkspaceControlLogoffAction "None"
Set-STFWebReceiverUserInterface -WebReceiverService $Rfw -WorkspaceControlAutoReconnectAtLogon $False
write-output "Sets default IIS page"
Set-STFWebReceiverService -WebReceiverService $Rfw -DefaultIISSite:$True

write-output "Trusted Domain"
$AuthService = Get-STFAuthenticationService -SiteId $SiteId -VirtualPath "/Citrix/StoreAuth"
Set-STFExplicitCommonOptions -AuthenticationService $AuthService -Domains (Get-WmiObject Win32_ComputerSystem).Domain -DefaultDomain (Get-WmiObject Win32_ComputerSystem).Domain -HideDomainField $true -AllowUserPasswordChange "Always"

write-output "Enable Session Reliability"
$gateway = Get-STFRoamingGateway -Name $GatewayName
Set-STFRoamingGateway -Gateway $gateway -SessionReliability $true

Stop-Transcript