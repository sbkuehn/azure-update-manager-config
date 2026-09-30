targetScope = 'subscription'

@description('Name of this subscription-level policy assignment.')
param policyAssignmentName string

@description('Azure region used to store the policy assignment identity.')
param policyAssignmentLocation string

@description('ARM ID of the guest patch maintenance configuration in this subscription.')
param maintenanceConfigurationResourceId string

@description('Operating system targeted by this assignment. Deploy one assignment per schedule and OS.')
@allowed([
  'Windows'
  'Linux'
])
param operatingSystemType string

@description('Optional machine locations. An empty array includes all locations.')
param locations array = []

@description('Optional machine resource group names. An empty array includes all resource groups in this subscription.')
param resourceGroups array = []

@description('Optional tag key/value filters for limiting which machines are targeted.')
param tagValues array = []

@description('How multiple tag filters are matched.')
@allowed([
  'All'
  'Any'
])
param tagOperator string = 'Any'

@description('Effect for the built-in policy.')
@allowed([
  'DeployIfNotExists'
  'Disabled'
])
param effect string = 'DeployIfNotExists'

@description('Set true only when this deployment is authorized to grant the built-in policy Contributor at subscription scope.')
param grantContributorRole bool = false

var policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a'
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource updateManagerPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: policyAssignmentName
  location: policyAssignmentLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Schedule recurring updates using Azure Update Manager (${operatingSystemType})'
    policyDefinitionId: policyDefinitionId
    parameters: {
      effect: {
        value: effect
      }
      locations: {
        value: locations
      }
      maintenanceConfigurationResourceId: {
        value: maintenanceConfigurationResourceId
      }
      operatingSystemTypes: {
        value: [
          operatingSystemType
        ]
      }
      resourceGroups: {
        value: resourceGroups
      }
      tagOperator: {
        value: tagOperator
      }
      tagValues: {
        value: tagValues
      }
    }
  }
}

resource policyContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (grantContributorRole) {
  name: guid(subscription().id, updateManagerPolicyAssignment.id, contributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: updateManagerPolicyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output policyAssignmentId string = updateManagerPolicyAssignment.id
output policyAssignmentPrincipalId string = updateManagerPolicyAssignment.identity.principalId