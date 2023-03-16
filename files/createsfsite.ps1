Param(
    [Parameter(Mandatory=$false)][Uri]$HostbaseUrl=$env:HostbaseUrl,
    [Parameter(Mandatory=$false)][long]$SiteId = 1,
    [string]$Farmtype = "XenDesktop",
    [Parameter(Mandatory=$false)][string[]]$FarmServers= @($env:FarmServer),
    [string]$StoreVirtualPath = "/Citrix/Store",
    [bool]$LoadbalanceServers = $true,
    [int]$Port = 80,
    [ValidateSet("HTTP","HTTPS","SSL")][string]$TransportType = $env:TransportType,
    [Parameter(Mandatory=$false)][Uri]$GatewayUrl=$env:GatewayUrl,
    # [Parameter(Mandatory=$false)][Uri]$GatewayCallbackUrl= "$env:HostbaseUrl/CitrixAuthService/AuthService.asmx",
    [Parameter(Mandatory=$false)][string[]]$GatewaySTAUrls=@($env:GatewaySTAUrls),
    [string]$GatewaySubnetIP,
    [Parameter(Mandatory=$false)][string]$GatewayName=$env:GatewayName
)

Start-Transcript -Path "C:\Logs\transcript.txt"

#Import ENV vars created
$importedsf = Import-Clixml "C:\Logs\sf-vars.xml"
$HostbaseUrl = $importedsf.HostbaseUrl
$FarmServers = $importedsf.FarmServers -split ","
$StoreVirtualPath = $importedsf.StoreVirtualPath
$TransportType = $importedsf.TransportType
$GatewayUrl = $importedsf.GatewayUrl
$GatewaySTAUrls = $importedsf.GatewaySTAUrls -split ","
$GatewayName = $importedsf.GatewayName

Set-StrictMode -Version 2.0

# Any failure is a terminating failure.
$ErrorActionPreference = 'Stop'
$ReportErrorShowStackTrace = $true
$ReportErrorShowInnerException = $true

# Import StoreFront modules. Required for versions of PowerShell earlier than 3.0 that do not support autoloading
Import-Module Citrix.StoreFront

# Create a remote access deployment using the RemoteAccessDeployment example
$scriptDirectory = "C:\install\"
$scriptPath = Join-Path $scriptDirectory "RemoteAccessDeployment.ps1"
& $scriptPath -HostbaseUrl $HostbaseUrl -SiteId $SiteId -FarmServers $FarmServers -StoreVirtualPath $StoreVirtualPath -Farmtype $Farmtype -LoadbalanceServers $LoadbalanceServers -Port $Port -TransportType $TransportType -GatewayUrl $GatewayUrl -GatewaySTAUrls $GatewaySTAUrls -GatewayName $GatewayName # -GatewayCallbackUrl ("$GatewayUrl/CitrixAuthService/AuthService.asmx") # Removed Callback URL, as not required
write-output "Local store configuration complete"

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