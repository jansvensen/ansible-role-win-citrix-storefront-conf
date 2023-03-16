#
# Copyright Citrix Systems, Inc. All rights reserved.
#
# Copied to this repository, as the CallBackURL is mandatory by default which was not required in our scenario. presales@devicetrust.com

Param(
    [Parameter(Mandatory=$true)][Uri]$HostbaseUrl,
    [Parameter(Mandatory=$true)][long]$SiteId = 1,
    [Parameter(Mandatory=$false)][string]$Farmtype = "XenDesktop",
    [Parameter(Mandatory=$true)][string[]]$FarmServers,
    [Parameter(Mandatory=$false)][string]$StoreVirtualPath = "/Citrix/Store",
    [Parameter(Mandatory=$false)][bool]$LoadbalanceServers = $false,
    [Parameter(Mandatory=$false)][int]$Port = 80,
    [Parameter(Mandatory=$false)][int]$SSLRelayPort = 443,
    [Parameter(Mandatory=$false)][ValidateSet("HTTP","HTTPS","SSL")][string]$TransportType = "HTTP",
    [Parameter(Mandatory=$true)][Uri]$GatewayUrl,
    [Parameter(Mandatory=$true)][string[]]$GatewaySTAUrls,
    [Parameter(Mandatory=$false)][string]$GatewaySubnetIP,
    [Parameter(Mandatory=$true)][string]$GatewayName
)

Set-StrictMode -Version 2.0

# Any failure is a terminating failure.
$ErrorActionPreference = 'Stop'
$ReportErrorShowStackTrace = $true
$ReportErrorShowInnerException = $true

# Import StoreFront modules. Required for versions of PowerShell earlier than 3.0 that do not support autoloading
Import-Module Citrix.StoreFront
Import-Module Citrix.StoreFront.Stores
Import-Module Citrix.StoreFront.Roaming

# Create a simple deployment by invoking the SimpleDeployment example
$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$scriptPath = Join-Path $scriptDirectory "SimpleDeployment.ps1"
& $scriptPath -HostbaseUrl $HostbaseUrl -SiteId $SiteId -FarmServers $FarmServers -StoreVirtualPath $StoreVirtualPath -Farmtype $Farmtype `
    -LoadbalanceServers $LoadbalanceServers -Port $Port  -SSLRelayPort $SSLRelayPort -TransportType $TransportType

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