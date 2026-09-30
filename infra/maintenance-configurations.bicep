targetScope = 'resourceGroup'

@description('Azure region for the maintenance configurations.')
param location string = resourceGroup().location

@description('Time zone used by both maintenance schedules.')
param timeZone string = 'UTC'

@description('Schedule start date in YYYY-MM-DD format.')
param startDate string

@description('Name of the Windows maintenance configuration.')
param windowsConfigurationName string = 'mc-windows-monthly'

@description('Name of the Linux maintenance configuration.')
param linuxConfigurationName string = 'mc-linux-daily'

resource windowsMaintenanceConfiguration 'Microsoft.Maintenance/maintenanceConfigurations@2023-09-01-preview' = {
  name: windowsConfigurationName
  location: location
  properties: {
    namespace: 'Microsoft.Maintenance'
    visibility: 'Custom'
    maintenanceScope: 'InGuestPatch'
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceWindow: {
      startDateTime: '${startDate} 22:00'
      duration: '03:55'
      recurEvery: 'Month Second Tuesday Offset4'
      timeZone: timeZone
    }
    installPatches: {
      rebootSetting: 'IfRequired'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
          'UpdateRollup'
          'Definition'
          'Updates'
        ]
      }
    }
  }
}

resource linuxMaintenanceConfiguration 'Microsoft.Maintenance/maintenanceConfigurations@2023-09-01-preview' = {
  name: linuxConfigurationName
  location: location
  properties: {
    namespace: 'Microsoft.Maintenance'
    visibility: 'Custom'
    maintenanceScope: 'InGuestPatch'
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceWindow: {
      startDateTime: '${startDate} 02:00'
      duration: '02:00'
      recurEvery: 'Day'
      timeZone: timeZone
    }
    installPatches: {
      rebootSetting: 'IfRequired'
      linuxParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
      }
    }
  }
}

output windowsMaintenanceConfigurationId string = windowsMaintenanceConfiguration.id
output linuxMaintenanceConfigurationId string = linuxMaintenanceConfiguration.id