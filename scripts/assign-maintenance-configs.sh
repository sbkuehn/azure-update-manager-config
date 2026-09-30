#!/usr/bin/env bash
set -euo pipefail

API_VERSION="2023-09-01-preview"
ASSIGNMENT_NAME="update-manager"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required but was not found in PATH." >&2
  exit 1
fi

CURRENT_SUBSCRIPTION_ID="$(az account show --query id --output tsv 2>/dev/null || true)"

prompt_required() {
  local label="$1"
  local value
  while true; do
    read -r -p "$label: " value
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi
    echo "A value is required." >&2
  done
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local value
  read -r -p "$label [$default_value]: " value
  printf '%s' "${value:-$default_value}"
}

VM_RESOURCE_GROUP="$(prompt_required 'Resource group containing the VMs')"
CONFIG_RESOURCE_GROUP="$(prompt_default 'Resource group containing the maintenance configurations' "$VM_RESOURCE_GROUP")"
WINDOWS_CONFIG_NAME="$(prompt_default 'Windows maintenance configuration name' 'mc-windows-monthly')"
LINUX_CONFIG_NAME="$(prompt_default 'Linux maintenance configuration name' 'mc-linux-daily')"

if [[ -n "$CURRENT_SUBSCRIPTION_ID" ]]; then
  read -r -p "Azure subscription ID [$CURRENT_SUBSCRIPTION_ID]: " SUBSCRIPTION_ID
  SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$CURRENT_SUBSCRIPTION_ID}"
else
  SUBSCRIPTION_ID="$(prompt_required 'Azure subscription ID')"
fi

CONFIG_BASE_URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$CONFIG_RESOURCE_GROUP/providers/Microsoft.Maintenance/maintenanceConfigurations"
WINDOWS_CONFIG_ID="$CONFIG_BASE_URL/$WINDOWS_CONFIG_NAME"
LINUX_CONFIG_ID="$CONFIG_BASE_URL/$LINUX_CONFIG_NAME"

az rest \
  --method get \
  --url "$WINDOWS_CONFIG_ID?api-version=$API_VERSION" \
  --subscription "$SUBSCRIPTION_ID" \
  --output none
az rest \
  --method get \
  --url "$LINUX_CONFIG_ID?api-version=$API_VERSION" \
  --subscription "$SUBSCRIPTION_ID" \
  --output none

VM_LIST="$(az vm list \
  --resource-group "$VM_RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[].[id,name,storageProfile.osDisk.osType]" \
  --output tsv)"

if [[ -z "$VM_LIST" ]]; then
  echo "No virtual machines were found in resource group '$VM_RESOURCE_GROUP'." >&2
  exit 1
fi

ASSIGNED_COUNT=0
SKIPPED_COUNT=0

while IFS=$'\t' read -r VM_ID VM_NAME OS_TYPE; do
  [[ -n "$VM_ID" ]] || continue

  case "$OS_TYPE" in
    Windows|windows)
      CONFIGURATION_ID="$WINDOWS_CONFIG_ID"
      ;;
    Linux|linux)
      CONFIGURATION_ID="$LINUX_CONFIG_ID"
      ;;
    *)
      echo "Skipping '$VM_NAME': unsupported or unknown OS type '$OS_TYPE'." >&2
      ((SKIPPED_COUNT += 1))
      continue
      ;;
  esac

  BODY="{\"properties\":{\"maintenanceConfigurationId\":\"$CONFIGURATION_ID\"}}"
  az rest \
    --method put \
    --url "$VM_ID/providers/Microsoft.Maintenance/configurationAssignments/$ASSIGNMENT_NAME?api-version=$API_VERSION" \
    --subscription "$SUBSCRIPTION_ID" \
    --body "$BODY" \
    --output none

  echo "Assigned '$VM_NAME' ($OS_TYPE)."
  ((ASSIGNED_COUNT += 1))
done <<< "$VM_LIST"

echo "Finished: $ASSIGNED_COUNT VM(s) assigned; $SKIPPED_COUNT VM(s) skipped."