@description(''Name for the Azure Container Registry'')
param acrName string

@description(''Name for the Container Apps Environment'')
param environmentName string = ''container-series-env''

@description(''Azure region'')
param location string = resourceGroup().location

@description(''Order service image tag'')
param serviceImageTag string = ''latest''

@description(''Order job image tag'')
param jobImageTag string = ''latest''

// Log Analytics Workspace (required for Container Apps)
resource logAnalytics ''Microsoft.OperationalInsights/workspaces@2022-10-01'' = {
  name: ''${environmentName}-logs''
  location: location
  properties: {
    sku: { name: ''PerGB2018'' }
    retentionInDays: 30
  }
}

// Azure Container Registry reference (assumed to exist)
resource acr ''Microsoft.ContainerRegistry/registries@2023-07-01'' existing = {
  name: acrName
}

// Container Apps Environment
resource environment ''Microsoft.App/managedEnvironments@2023-05-01'' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: ''log-analytics''
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Container App: Order Service
resource orderService ''Microsoft.App/containerApps@2023-05-01'' = {
  name: ''order-service''
  location: location
  identity: {
    type: ''SystemAssigned''
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: ''http''
      }
      dapr: {
        enabled: true
        appId: ''order-service''
        appPort: 8080
        appProtocol: ''http''
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: ''system''
        }
      ]
    }
    template: {
      containers: [
        {
          name: ''order-service''
          image: ''${acr.properties.loginServer}/order-service:${serviceImageTag}''
          resources: {
            cpu: json(''0.5'')
            memory: ''1Gi''
          }
          env: [
            { name: ''ENVIRONMENT'', value: ''production'' }
            { name: ''DAPR_ENABLED'', value: ''true'' }
          ]
        }
      ]
      scale: {
        minReplicas: 0  // Scale to zero!
        maxReplicas: 10
        rules: [
          {
            name: ''http-scaling''
            http: {
              metadata: {
                concurrentRequests: ''100''
              }
            }
          }
        ]
      }
    }
  }
}

// Grant AcrPull to order service
resource acrPullService ''Microsoft.Authorization/roleAssignments@2022-04-01'' = {
  name: guid(acr.id, orderService.id, ''AcrPull'')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(''Microsoft.Authorization/roleDefinitions'', ''7f951dda-4ed3-4680-a7ca-43fe172d538d'')
    principalId: orderService.identity.principalId
    principalType: ''ServicePrincipal''
  }
}

// Container App Job: Order Processor
resource orderJob ''Microsoft.App/jobs@2023-05-01'' = {
  name: ''order-processor-job''
  location: location
  identity: {
    type: ''SystemAssigned''
  }
  properties: {
    environmentId: environment.id
    configuration: {
      triggerType: ''Schedule''
      scheduleTriggerConfig: {
        cronExpression: ''0 */6 * * *''  // Every 6 hours
        parallelism: 1
        replicaCompletionCount: 1
      }
      replicaTimeout: 300
      replicaRetryLimit: 1
      registries: [
        {
          server: acr.properties.loginServer
          identity: ''system''
        }
      ]
    }
    template: {
      containers: [
        {
          name: ''order-processor''
          image: ''${acr.properties.loginServer}/order-job:${jobImageTag}''
          resources: {
            cpu: json(''0.25'')
            memory: ''512Mi''
          }
          env: [
            { name: ''ENVIRONMENT'', value: ''production'' }
          ]
        }
      ]
    }
  }
}

// Grant AcrPull to job
resource acrPullJob ''Microsoft.Authorization/roleAssignments@2022-04-01'' = {
  name: guid(acr.id, orderJob.id, ''AcrPull'')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(''Microsoft.Authorization/roleDefinitions'', ''7f951dda-4ed3-4680-a7ca-43fe172d538d'')
    principalId: orderJob.identity.principalId
    principalType: ''ServicePrincipal''
  }
}

output serviceUrl string = ''https://${orderService.properties.configuration.ingress.fqdn}''
output environmentId string = environment.id
