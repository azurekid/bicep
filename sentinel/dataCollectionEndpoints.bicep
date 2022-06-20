@description('Specifies the name of the Data Collection Endpoint to create.')
param dataCollectionEndpointName string

@description('Specifies the location in which to create the Data Collection Endpoint.')
param location string = resourceGroup().location

resource dataCollectionEndpoints 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' = {
  name: dataCollectionEndpointName
  location: location
  tags: {}
  kind: 'string'
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Disabled'
    }
  }
}

output Name string = dataCollectionEndpoints.name
output ImmutableId string = dataCollectionEndpoints.properties.immutableId
output logIngestionEndpoint string = dataCollectionEndpoints.properties.logsIngestion.endpoint
output resourceId string = dataCollectionEndpoints.id
