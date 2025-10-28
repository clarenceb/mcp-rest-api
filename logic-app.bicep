@description('Name of the Logic App')
param name string

@description('Add unique suffix to Logic App name for global uniqueness')
param addUniqueSuffix bool = true

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Location for all resources')
param location string = resourceGroup().location

@description('Use 32-bit worker process')
param use32BitWorkerProcess bool = false

@description('FTPS state')
@allowed([
  'AllAllowed'
  'FtpsOnly'
  'Disabled'
])
param ftpsState string = 'Disabled'

@description('Storage account name')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('.NET Framework version')
param netFrameworkVersion string = 'v8.0'

@description('SKU tier')
@allowed([
  'WorkflowStandard'
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'WorkflowStandard'

@description('SKU code')
@allowed([
  'WS1'
  'WS2'
  'WS3'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param skuCode string = 'WS1'

var uniqueSuffix = uniqueString(resourceGroup().id)
var logicAppName = addUniqueSuffix ? '${name}-${uniqueSuffix}' : name

@description('Hosting plan name')
param hostingPlanName string = 'plan-${name}'

@description('Server farm resource group')
param serverFarmResourceGroup string = resourceGroup().name

@description('Application Insights name')
param appInsightsName string = 'appi-${name}'

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string = 'log-${name}'

// User-assigned managed identity for storage access
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${logicAppName}'
  location: location
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: {}
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    DisableLocalAuth: false
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  tags: {}
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false  // Disabled per MCAPS requirements
    publicNetworkAccess: 'Enabled'
  }
}

// Role assignment: Storage Blob Data Contributor for managed identity
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, userManagedIdentity.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// App Service Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  tags: {}
  sku: {
    tier: sku
    name: skuCode
  }
  kind: ''
  properties: {
    reserved: false
    zoneRedundant: false
  }
}

// Logic App (Function App with Workflows)
resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: logicAppName
  location: location
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
  }
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__managedIdentityResourceId'
          value: userManagedIdentity.id
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'FUNCTIONS_INPROC_NET8_ENABLED'
          value: '1'
        }
        {
          name: 'LOGIC_APPS_POWERSHELL_VERSION'
          value: '7.4'
        }
      ]
      cors: {}
      use32BitWorkerProcess: use32BitWorkerProcess
      ftpsState: ftpsState
      netFrameworkVersion: netFrameworkVersion
    }
    clientAffinityEnabled: false
    virtualNetworkSubnetId: null
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: '/subscriptions/${subscriptionId}/resourcegroups/${serverFarmResourceGroup}/providers/Microsoft.Web/serverfarms/${hostingPlanName}'
  }
  dependsOn: [
    hostingPlan
    storageAccount
    storageRoleAssignment
  ]
}

// Basic Publishing Credentials Policy - SCM
resource siteScmPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: 'scm'
  parent: logicApp
  properties: {
    allow: false
  }
}

// Basic Publishing Credentials Policy - FTP
resource siteFtpPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: 'ftp'
  parent: logicApp
  properties: {
    allow: false
  }
}

// Outputs
output logicAppName string = logicApp.name
output logicAppUrl string = 'https://${logicApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output managedIdentityId string = userManagedIdentity.id
output appInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
