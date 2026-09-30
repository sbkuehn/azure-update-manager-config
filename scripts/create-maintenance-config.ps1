$ErrorActionPreference = 'Stop'

$apiVersion = '2023-09-01-preview'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required but was not found in PATH.'
}

$currentSubscriptionId = az account show --query id --output tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    $currentSubscriptionId = ''
}

function Read-RequiredValue {
    param([string]$Prompt)

    do {
        $value = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host 'A value is required.' -ForegroundColor Yellow
        }
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

$resourceGroup = Read-RequiredValue 'Resource group name'
$location = Read-RequiredValue 'Azure region (for example, eastus)'
$timeZone = Read-RequiredValue 'Time zone (for example, UTC or Central Standard Time)'
$startDate = Read-RequiredValue 'Schedule start date (YYYY-MM-DD)'

if ($startDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    throw 'Start date must use YYYY-MM-DD format.'
}

if ($currentSubscriptionId) {
    $subscriptionInput = Read-Host "Azure subscription ID [$currentSubscriptionId]"
    if ([string]::IsNullOrWhiteSpace($subscriptionInput)) {
        $subscriptionId = $currentSubscriptionId
    }
    else {
        $subscriptionId = $subscriptionInput.Trim()
    }
}
else {
    $subscriptionId = Read-RequiredValue 'Azure subscription ID'
}

$baseUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations"

az group create `
    --name $resourceGroup `
    --location $location `
    --subscription $subscriptionId `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create or verify the resource group.'
}

$windowsBody = @{
    location   = $location
    properties = @{
        namespace           = 'Microsoft.Maintenance'
        visibility          = 'Custom'
        maintenanceScope    = 'InGuestPatch'
        extensionProperties = @{ InGuestPatchMode = 'User' }
        maintenanceWindow   = @{
            startDateTime = "$startDate 22:00"
            duration      = '03:55'
            recurEvery    = 'Month Second Tuesday Offset4'
            timeZone      = $timeZone
        }
        installPatches      = @{
            rebootSetting    = 'IfRequired'
            windowsParameters = @{
                classificationsToInclude = @('Critical', 'Security', 'UpdateRollup', 'Definition', 'Updates')
            }
        }
    }
} | ConvertTo-Json -Depth 10 -Compress

az rest `
    --method put `
    --url "$baseUrl/mc-windows-monthly?api-version=$apiVersion" `
    --headers 'Content-Type=application/json' `
    --body $windowsBody `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create the Windows maintenance configuration.'
}

$linuxBody = @{
    location   = $location
    properties = @{
        namespace           = 'Microsoft.Maintenance'
        visibility          = 'Custom'
        maintenanceScope    = 'InGuestPatch'
        extensionProperties = @{ InGuestPatchMode = 'User' }
        maintenanceWindow   = @{
            startDateTime = "$startDate 02:00"
            duration      = '02:00'
            recurEvery    = 'Day'
            timeZone      = $timeZone
        }
        installPatches      = @{
            rebootSetting = 'IfRequired'
            linuxParameters = @{
                classificationsToInclude = @('Critical', 'Security')
            }
        }
    }
} | ConvertTo-Json -Depth 10 -Compress

az rest `
    --method put `
    --url "$baseUrl/mc-linux-daily?api-version=$apiVersion" `
    --headers 'Content-Type=application/json' `
    --body $linuxBody `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create the Linux maintenance configuration.'
}

Write-Host 'Maintenance configurations created successfully.'