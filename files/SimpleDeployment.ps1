#
# Copyright Citrix Systems, Inc. All rights reserved.
#
# Copied to this repository, as the CallBackURL is mandatory by default which was not required in our scenario. presales@devicetrust.com

Param(
    [Parameter(Mandatory=$true)][Uri]$HostbaseUrl,
    [Parameter(Mandatory=$false)][long]$SiteId = 1,
    [Parameter(Mandatory=$false)][ValidateSet("XenDesktop","XenApp","AppController","VDIinaBox")][string]$Farmtype = "XenDesktop",
    [Parameter(Mandatory=$true)][string[]]$FarmServers,
    [Parameter(Mandatory=$false)][string]$StoreVirtualPath = "/Citrix/Store",
    [Parameter(Mandatory=$false)][bool]$LoadbalanceServers = $false,
    [Parameter(Mandatory=$false)][int]$Port = 80,
    [Parameter(Mandatory=$false)][int]$SSLRelayPort = 443,
    [Parameter(Mandatory=$false)][ValidateSet("HTTP","HTTPS","SSL")][string]$TransportType = "HTTP"
)

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

# Determine the Authentication and Receiver virtual path to use based of the Store
$authenticationVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Auth"
$receiverVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Web"

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
# SIG # Begin signature block
# MIIb+QYJKoZIhvcNAQcCoIIb6jCCG+YCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAsWwcUZyeSkxOd
# kzrs3DNr1wC4qJoUzBeT2w4F7ARPG6CCCpMwggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggVbMIIEQ6ADAgECAhAJw7HqIJeu0eJD2QJME8FaMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjAwNjE4MDAwMDAw
# WhcNMjEwNjIzMTIwMDAwWjCBlzELMAkGA1UEBhMCVVMxEDAOBgNVBAgTB0Zsb3Jp
# ZGExGDAWBgNVBAcTD0ZvcnQgTGF1ZGVyZGFsZTEdMBsGA1UEChMUQ2l0cml4IFN5
# c3RlbXMsIEluYy4xHjAcBgNVBAsTFVhlbkFwcChTZXJ2ZXIgU0hBMjU2KTEdMBsG
# A1UEAxMUQ2l0cml4IFN5c3RlbXMsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCs/+np0w47UQEaH1+gsQb100qzUk6J4hlSUKtLSZrRiI7n+Qih
# 1mhnotThnpH7T/D4+GOWxs1t7E+hsEPPeAdJ4sLv556nYelQ2zFn8vHmQA4uMdKm
# L1Q+1sZqv6fqgJ+fIkRtopC1YhFLJJnNmLGvXA/LNdYAkd6y1puec5ZcQW4O+emi
# Va0kSqSHH03MZuoRAqMK/fNzaf14VUQEo+Ow1owa2DHl0K7RN+9EYXB0UrR4SoT4
# c3BnwyqMULE/I4m50v1mKFIzu10bFJLkHVH4FiOhTLr32d+vJlZO0mjicdRdixfc
# HnNo+Xb6Ispy0+hxktAIYqpIlhDywXytSYCFAgMBAAGjggHFMIIBwTAfBgNVHSME
# GDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQUvE2AHMSllVUT+12Q
# +ptnVSBWuPswDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcG
# A1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# c2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAq
# MCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeB
# DAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQBcie+7QppY9QD/jVQb69t0iXyC
# HKeaH/Gf+C3GFe29nsWcS26c66glVKZ2Fv3oOGlyNV893BV1nnoz2on/mXUwNjb/
# AAoQ7l70xTFKVMjQ0cr++MzNuu69yPCj6vn8/JHLBJ3ERJakTANh65QiTtIRv8Ej
# DkmR7K3BLw1kQ5riA578V1760fn9q6ve7vD3f4itxii+sITDEMl8SGkJ7nCHs1Kg
# mam4YIMYYMFZA8bGIplfSLMnE+A/+FiDtie9ctWYJclBZFTK+NtFKVPbHZIEIsUR
# ITiSogtIYqzxGQS8ap5xVAqQM82EE3XmXOGjoscDk4L2EJ9Qa/mHebcweSRHMYIQ
# vDCCELgCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQg
# U0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQCcOx6iCXrtHiQ9kCTBPB
# WjANBglghkgBZQMEAgEFAKCBvDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg5uRb
# LXf8o32bSS38AUqgqVf/A3xrlSou/YUaaN0oxJYwUAYKKwYBBAGCNwIBDDFCMECg
# JIAiAEMAaQB0AHIAaQB4ACAAUwB0AG8AcgBlAEYAcgBvAG4AdKEYgBZodHRwOi8v
# d3d3LmNpdHJpeC5jb20gMA0GCSqGSIb3DQEBAQUABIIBABmsUs/EJ83uIwWPxDf5
# 8WBRfndXDmNMDqJNcm4+Nch8WLfGSJgVAclgTyF9ipsyN9P7Km+6ut+lE+R+Slg1
# SW0tv7PhaFSOGrRG2P2wxJPr8zbe2APo04ettjU2K2Zv3myxBUQApoqaO1otIzxW
# 0e1i0q0dHolO6SFsSKH6ayYEa6I05MK/goyzd/iqpRX83LC4DtDEjs6uE9RslUuq
# 8svMOTC/Iu4w8E6P9IAeQTPmHqVKfJU1NN7kAUOPL8hVRuBDVE2YoZzw7UxfTink
# aiPGcwoIinT+v5Bbh/RV2/ydhu4dztpay0WFTKTNGBfXvojWycZQmm+DzltCwXgL
# cYehgg5HMIIOQwYKKwYBBAGCNwMDATGCDjMwgg4vBgkqhkiG9w0BBwKggg4gMIIO
# HAIBAzEPMA0GCWCGSAFlAwQCAQUAMIHSBgsqhkiG9w0BCRABBKCBwgSBvzCBvAIB
# AQYEKgMEBTAxMA0GCWCGSAFlAwQCAQUABCDsJRpguWCJwZd+4+9HE9cXe5wOXWuf
# /GI/g+++vxaSEwIHBcBZaoDHKxgPMjAyMTA0MTkyMDQ1NTVaoGSkYjBgMQswCQYD
# VQQGEwJVUzEdMBsGA1UEChMUQ2l0cml4IFN5c3RlbXMsIEluYy4xDTALBgNVBAsT
# BEdMSVMxIzAhBgNVBAMTGkNpdHJpeCBUaW1lc3RhbXAgUmVzcG9uZGVyoIIKXTCC
# BSQwggQMoAMCAQICEAqSXSRVgDYm4YegBXCaJZAwDQYJKoZIhvcNAQELBQAwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQTAeFw0xODA4MDEwMDAwMDBaFw0yMzA5MDEwMDAwMDBa
# MGAxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRDaXRyaXggU3lzdGVtcywgSW5jLjEN
# MAsGA1UECxMER0xJUzEjMCEGA1UEAxMaQ2l0cml4IFRpbWVzdGFtcCBSZXNwb25k
# ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDY1rSeHnKVXwd+GJ8X
# 2Db29UadiWwbufxvQaHvGhAUHNs4nVvNqLrGa149kA9qlANRHvJ6KLdShnEHWNFs
# 820iFOyh3jweSmhElo7R1SdwVulvavlNuJtnTw/6GjcRseg7Q+zNDZTASEWSqO2j
# SLESJR5IO8JzUM6otI05MwTu0t+IaJWqoX7kIKpICqhpnKEiF1ajZhBWlPuZKWBa
# qTKOsdbEgIH4DRHCIBo54/Mc3VNa54eojWDMTrfILjFpNs/iijW7sR+mCwAPVQWF
# uNe2X9ed/+S+Ho7scVIQqdNyZKFCFo0kY895tuBw/SvDUoCdAHQ6TRPGT5iCQjBY
# vRWHAgMBAAGjggHGMIIBwjAfBgNVHSMEGDAWgBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAdBgNVHQ4EFgQUtWN+wIV1Bz2mLr0v0lLFhRYrEm0wDAYDVR0TAQH/BAIwADAO
# BgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwTwYDVR0gBEgw
# RjA3BglghkgBhv1sBwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNl
# cnQuY29tL0NQUzALBglghkgBhv1sAxUwcQYDVR0fBGowaDAyoDCgLoYsaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmwwMqAwoC6GLGh0
# dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMuY3JsMIGFBggr
# BgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsF
# AAOCAQEAa0OLR4Hbt+5mnZmDC+iJH2/GzVqK4rYqBnK5VX7DBBnSzSwLD2KqzKPZ
# mZjcykxO1FcxlXcG/gn8/SEXw+oZiuoYRLqJvlzcwvCxkN6O1NnnXmBf8biHBWQM
# JkJ1zqFZeMg1iq38mpTiDvcKUOmw1e39Aj2vI90I9njSdrtqip0RPseSM/I+ZbI0
# HnnyK4hlR3du0fd2otJYvVmTE/SijgJNOkdGdKshu9I14aFKeDq+XJb+ZplSYJsa
# 9YTI1YO7/eVhmOdKdvnH4ai5VYrtnLtCwoN9SFG9JW02DW4GNXnGtnK/BdKaVZ67
# eeWFX29TPNIbo/Q3mGI3hUipHDfusTCCBTEwggQZoAMCAQICEAqhJdbWMht+QeQF
# 2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMb
# RGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTE2MDEwNzEyMDAwMFoXDTMx
# MDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQg
# U0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6gpnFOVQoV7YjSsQOB0UzURB90Pl9
# TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjWahQAOPcuHjvuzKb2Mln+X2U/4Jvr
# 40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8CdPuXciaC1Tj
# qAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTGTSQjMF287DxgaqwvB8z98OpH2YhQ
# Xv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7HgXQhBlyF/EX
# Bu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOCAc4wggHKMB0G
# A1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAWgBRF66Kv9JLL
# gjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIB
# hjATBgNVHSUEDDAKBggrBgEFBQcDCDB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQBgNVHSAESTBH
# MDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNl
# cnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggEBAHGVEulR
# h1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9xafDDiBCLK938ysfDCFaKrcFNB1q
# rpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIlHsS6HHssIeLWWywUNUMEaLLbdQLg
# cseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8pieV4H9YLFKWA1xJHcLN11ZOFk362
# kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4UijGHKeZR+WfyMD+NvtQEmtmyl7odR
# IeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZdtnR79VYzIi8i
# NrJLokqV2PWmjlIxggLOMIICygIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYD
# VQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBAhAK
# kl0kVYA2JuGHoAVwmiWQMA0GCWCGSAFlAwQCAQUAoIIBGDAaBgkqhkiG9w0BCQMx
# DQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIJykvdx5m1DX97LTRSI+S0BR
# VGj+T90GgySYmRa4QeVXMIHIBgsqhkiG9w0BCRACLzGBuDCBtTCBsjCBrwQgsCrO
# 26Gy12Ws1unFBnpWG9FU4YUyDBzPXmMmtqVvLqMwgYowdqR0MHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3Rh
# bXBpbmcgQ0ECEAqSXSRVgDYm4YegBXCaJZAwDQYJKoZIhvcNAQEBBQAEggEAylnh
# +N3JoCloRZjzSVmZoval6VcHMlJjpJnbzscT5pqoeUDPvdaHay3T7G09TKYui4aS
# 9uYkpq2S0V3/52/VL8xEe4Job4win0aJ/nTX0GqDB9GrXScUILcTdrYNyEY4B6FU
# zF2G39WvshEA2nk016ZF+HPmlblJV7KAYyC+NZPuVYmBdA48/d6Usl/BoQfSH7en
# wWhbk6xjsfmZEnfImIvY4DCgvsh1H85jr/CNuaWZKj/aT476WEKjXHuQLBbAVbfP
# iHiEhRGjtne/y8ijlafRJb/y7eOA+9wHbEEFutWACfQ1yE2NB+ILZd/zU/rRKn97
# nuKuIykkTYn7S+G7Fw==
# SIG # End signature block
