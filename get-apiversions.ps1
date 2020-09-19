<#
.SYNOPSIS
Checks the apiVersion per resource defined in a bicep file.

.DESCRIPTION
Iterates through all bicep files in the defined location and validates if the
latest version of the resource API is used to identify technical dept.

.PARAMETER FilesPath
The path in which (sub)folders will be scanned for bicep files

.PARAMETER Preview
Switch to exclude the preview versions of the API's

.OUTPUTS
None
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [String] $FilesPath,

    [Parameter(Mandatory = $false)]
    [switch] $Preview = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bicepFiles = @()

Write-Output 'Gathering all available resource providers...'
$resourcesProviders = Get-AzResourceProvider

function Get-ApiVersion ($ResourceProvider, $apiVersion) {
    Write-Verbose $ResourceProvider
    $typeArray = ($ResourceProvider) -Split ('/'), 2

    switch ($typeArray[1]) {
        "locks" {
            $ProviderNamespace = "Microsoft.Authorization"
            $type = $typeArray[1]
          }
        "diagnosticSettings" {
            $ProviderNamespace = "Microsoft.Insights"
            $type = $typeArray[1]
        }
        default {
            if ($ResourceProvider -like '*locks*') {
                $ProviderNamespace = "Microsoft.Authorization"
                $type = "locks"
            }
            elseif ($ResourceProvider -like '*diagnosticSettings*') {
                $ProviderNamespace = "Microsoft.Insights"
                $type = "diagnosticSettings"
            }
            else {
                $ProviderNamespace = $typeArray[0]
                $type = $typeArray[1]
            }
        }
    }

    try {
        $apiVersions = ((($resourcesProviders | Where-Object { $_.ProviderNamespace -eq $ProviderNamespace }).ResourceTypes `
                | Where-Object { $_.ResourceTypeName -eq $type }) `
                | Sort-Object -Descending)

            if($apiVersions) {
                if ($Preview) {
                    $latestApi = ($apiVersions.ApiVersions | Sort-Object -Descending)
                }
                else {
                    $latestApi = ($apiVersions.ApiVersions | Where-Object { $_ -notlike "*preview*" } | Sort-Object -Descending)
                }

                $hashTable = @{
                    "Resource Provider"     = $ResourceProvider
                    "Current API version"   = $apiVersion
                    "Latest API version"    = $latestApi[0]
                }

                $d1 = [datetime]::ParseExact("$apiVersion".Substring(0, 10), "yyyy-MM-dd", $null)
                $d2 = [datetime]::ParseExact($latestApi[0].Substring(0, 10), "yyyy-MM-dd", $null)
                $ts = (New-TimeSpan -Start $d1 -End $d2).Days.toString()

                if ($ts -ne "0") {
                    Write-Warning "New API version available"
                    Write-Output $hashTable
                    $hashTable.Clear()
                }
            }
            else {
                Write-Output "resource provider: $($ResourceProvider) not found. Please check the Microsoft documentation"
            }
    }
    catch {
        Write-Error $error[0]
    }
}

$bicepFiles = @(Get-ChildItem -Path $FilesPath -Recurse -Filter "*.bicep")

if ($bicepFiles) {
    $fileCounter = 1
    ForEach ($bicepFile in $bicepFiles) {
        Write-Output "Processing Bicep template $fileCounter/$($bicepFiles.Count) with name '$($bicepFile.Name)'."
        $fileCounter++
    
        $resources = ($bicepFile | `
            Select-String -Pattern "(?<=')(.*)(?=' )" `
            -AllMatches | `
            ForEach-Object { $_.matches.value })

        foreach ($resource in $resources) {
            $object = $resource -split '@'
            Get-ApiVersion `
                -ResourceProvider $($object[0]) `
                -apiVersion $($object[1])
            }   
    }
}
