targetScope = 'resourceGroup'

@description('Azure region to deploy into. Must support the target model in your subscription/region.')
param location string = resourceGroup().location

@description('Name of the Foundry (AIServices) account resource.')
param foundryName string

@description('Name of the Foundry project (child of the AIServices account).')
param projectName string = 'agentic-azure-sql'

@description('Deployment name (this becomes the deployment you call in the OpenAI-compatible endpoint).')
param deploymentName string = 'gpt5mini'

@description('Model name from the catalog.')
param modelName string = 'gpt-5-mini'

@description('Model version. If omitted, Azure may assign a default; providing a known version is more deterministic.')
param modelVersion string = '2025-08-07'

@description('Cognitive Services account SKU. S0 is commonly used for AIServices.')
param accountSkuName string = 'S0'

@description('Deployment SKU name. Common options include Standard, GlobalStandard, DataZoneStandard depending on residency/throughput needs.')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity units (meaning depends on SKU/type).')
param deploymentCapacity int = 10

@description('Optional tags.')
param tags object = {}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  sku: {
    name: accountSkuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    // Enables project child resources under the account for Foundry
    allowProjectManagement: true
    // Recommended for stable endpoint naming
    customSubDomainName: toLower(foundryName)
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  name: projectName
  parent: foundry
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: projectName
    description: 'Project created via Bicep'
  }
  tags: tags
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' = {
  name: deploymentName
  parent: foundry
  sku: {
    name: deploymentSkuName
    capacity: deploymentCapacity
  }
  properties: {
    model: {
      name: modelName
      version: modelVersion
      format: 'OpenAI'
    }
    deploymentState: 'Running'
  }
}

// Outputs you can paste into .env
output azureSubscriptionId string = subscription().subscriptionId
output foundryInstanceId string = foundry.id
output foundryProjectId string = project.id
output modelDeploymentName string = modelDeployment.name
output modelDeploymentId string = modelDeployment.id
output foundryEndpoint string = foundry.properties.endpoint
