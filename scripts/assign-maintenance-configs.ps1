$ErrorActionPreference = 'Stop'

$apiVersion = '2023-09-01-preview'
$assignmentName = 'update-manager'

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

function Read-Value {
    param(
        [string]$Prompt,
        [string]$DefaultValue
    )

    $value = Read-Host "$Prompt [$DefaultValue]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value.Trim()
}

$vmResourceGroup = Read-RequiredValue 'Resource group containing the VMs'
$configResourceGroup = Read-Value 'Resource group containing the maintenance configurations' $vmResourceGroup
$windowsConfigName = Read-Value 'Windows maintenance configuration name' 'mc-windows-monthly'
$linuxConfigName = Read-Value 'Linux maintenance configuration name' 'mc-linux-daily'

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

$configBaseUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$configResourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations"
$windowsConfigId = "$configBaseUrl/$windowsConfigName"
$linuxConfigId = "$configBaseUrl/$linuxConfigName"

az rest `
    --method get `
    --url "$windowsConfigId`?api-version=$apiVersion" `
    --subscription $subscriptionId `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw "Could not find Windows maintenance configuration '$windowsConfigName' in '$configResourceGroup'."
}

az rest `
    --method get `
    --url "$linuxConfigId`?api-version=$apiVersion" `
    --subscription $subscriptionId `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw "Could not find Linux maintenance configuration '$linuxConfigName' in '$configResourceGroup'."
}

$vmJson = az vm list `
    --resource-group $vmResourceGroup `
    --subscription $subscriptionId `
    --query '[].{id:id,name:name,osType:storageProfile.osDisk.osType}' `
    --output json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to list virtual machines in '$vmResourceGroup'."
}

$vms = @($vmJson | ConvertFrom-Json)
if ($vms.Count -eq 0) {
    throw "No virtual machines were found in resource group '$vmResourceGroup'."
}

$assignedCount = 0
$skippedCount = 0

foreach ($vm in $vms) {
    switch -Regex ([string]$vm.osType) {
        '^Windows$' { $configurationId = $windowsConfigId; break }
        '^Linux$' { $configurationId = $linuxConfigId; break }
        default {
            Write-Warning "Skipping '$($vm.name)': unsupported or unknown OS type '$($vm.osType)'."
            $skippedCount++
            continue
        }
    }

    $body = @{
        properties = @{
            maintenanceConfigurationId = $configurationId
        }
    } | ConvertTo-Json -Depth 5 -Compress

    $assignmentUrl = "$($vm.id)/providers/Microsoft.Maintenance/configurationAssignments/$assignmentName`?api-version=$apiVersion"
    az rest `
        --method put `
        --url $assignmentUrl `
        --subscription $subscriptionId `
        --body $body `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign '$($vm.name)' to its maintenance configuration."
    }

    Write-Host "Assigned '$($vm.name)' ($($vm.osType))."
    $assignedCount++
}

Write-Host "Finished: $assignedCount VM(s) assigned; $skippedCount VM(s) skipped."