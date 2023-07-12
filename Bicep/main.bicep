@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location


@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
])
param runtime string = 'dotnet'
param storageAccountName string
param applicationInsightsName string
param functionAppName string
param vaultname string
param hostingPlanName string

var storageBlobDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

var functionWorkerRuntime = runtime




resource dummySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
 apiVersion: '2019-09-01'
  name: '${vaultname}/AzureFunctionsConfiguration--DummySecretName'
  properties: {
    value: 'verysecertvalue'
  }
}

resource AzureWebJobsStorage 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  apiVersion: '2019-09-01'
   name: '${vaultname}/AzureFunctionsConfiguration--AzureWebJobsStorage'
   properties: {
     value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
   }
 }

 resource CONTENTAZUREFILECONNECTIONSTRING 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  apiVersion: '2019-09-01'
   name: '${vaultname}/AzureFunctionsConfiguration--CONTENTAZUREFILECONNECTIONSTRING'
   properties: {
     value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
   }
 }

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: vaultname
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: 'a137c072-7431-41e9-bcda-6e5234ba5e68'
        tenantId: subscription().tenantId
        permissions: {
          keys: ['get', 'list']
          secrets: ['get', 'list']
        }
      }
      {
        objectId: functionApp.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          keys: ['get', 'list']
          secrets: ['get', 'list']
        }
      }
    ]
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(VaultName=${vaultname};SecretName=AzureFunctionsConfiguration--AzureWebJobsStorage)'
        }
        {
          name: 'DummySecret'
          value: '@Microsoft.KeyVault(VaultName=${vaultname};SecretName=AzureFunctionsConfiguration--DummySecretName)'
        }
        {
          name: 'DummySecret'
          value: '@Microsoft.KeyVault(VaultName=${vaultname};SecretName=AzureFunctionsConfiguration--DummySecretName)'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: '@Microsoft.KeyVault(VaultName=${vaultname};SecretName=AzureFunctionsConfiguration--CONTENTAZUREFILECONNECTIONSTRING)'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}
/* 
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(uniqueString('valutreader'))
  properties: {
    principalId: reference(concat('Microsoft.Web/sites/', functionAppName), '2019-08-01', 'Full').identity.principalId
    roleDefinitionId: '21090545-7ca7-4776-b22c-e363652d74d2' // Replace with the appropriate role definition ID for read access
    scope: resourceId('Microsoft.KeyVault/vaults', vaultname)
  }
}
*/
resource storageFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, functionApp.name, storageBlobDataContributorRole)
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRole
  }
}

resource kvFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, functionApp.name, keyVaultSecretsUserRole)
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}
