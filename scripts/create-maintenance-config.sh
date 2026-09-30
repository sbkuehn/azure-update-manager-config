#!/usr/bin/env bash
set -euo pipefail

API_VERSION="2023-09-01-preview"

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

RESOURCE_GROUP="$(prompt_required 'Resource group name')"
LOCATION="$(prompt_required 'Azure region (for example, eastus)')"
TIME_ZONE="$(prompt_required 'Time zone (for example, UTC or Central Standard Time)')"
START_DATE="$(prompt_required 'Schedule start date (YYYY-MM-DD)')"

if [[ ! "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Start date must use YYYY-MM-DD format." >&2
  exit 1
fi

if [[ -n "$CURRENT_SUBSCRIPTION_ID" ]]; then
  read -r -p "Azure subscription ID [$CURRENT_SUBSCRIPTION_ID]: " SUBSCRIPTION_ID
  SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$CURRENT_SUBSCRIPTION_ID}"
else
  SUBSCRIPTION_ID="$(prompt_required 'Azure subscription ID')"
fi

BASE_URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Maintenance/maintenanceConfigurations"

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --subscription "$SUBSCRIPTION_ID" \
  --output none

WINDOWS_BODY=$(cat <<JSON
{
  "location": "$LOCATION",
  "properties": {
    "namespace": "Microsoft.Maintenance",
    "visibility": "Custom",
    "maintenanceScope": "InGuestPatch",
    "extensionProperties": {
      "InGuestPatchMode": "User"
    },
    "maintenanceWindow": {
      "startDateTime": "${START_DATE} 22:00",
      "duration": "03:55",
      "recurEvery": "Month Second Tuesday Offset4",
      "timeZone": "$TIME_ZONE"
    },
    "installPatches": {
      "rebootSetting": "IfRequired",
      "windowsParameters": {
        "classificationsToInclude": [
          "Critical",
          "Security",
          "UpdateRollup",
          "Definition",
          "Updates"
        ]
      }
    }
  }
}
JSON
)

az rest \
  --method put \
  --url "$BASE_URL/mc-windows-monthly?api-version=$API_VERSION" \
  --headers "Content-Type=application/json" \
  --body "$WINDOWS_BODY" \
  --output none

LINUX_BODY=$(cat <<JSON
{
  "location": "$LOCATION",
  "properties": {
    "namespace": "Microsoft.Maintenance",
    "visibility": "Custom",
    "maintenanceScope": "InGuestPatch",
    "extensionProperties": {
      "InGuestPatchMode": "User"
    },
    "maintenanceWindow": {
      "startDateTime": "${START_DATE} 02:00",
      "duration": "03:55",
      "recurEvery": "Day",
      "timeZone": "$TIME_ZONE"
    },
    "installPatches": {
      "rebootSetting": "IfRequired",
      "linuxParameters": {
        "classificationsToInclude": [
          "Critical",
          "Security"
        ]
      }
    }
  }
}
JSON
)

az rest \
  --method put \
  --url "$BASE_URL/mc-linux-daily?api-version=$API_VERSION" \
  --headers "Content-Type=application/json" \
  --body "$LINUX_BODY" \
  --output none

echo "Maintenance configurations created successfully."