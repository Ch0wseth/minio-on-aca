@description('Région Azure')
param location string = resourceGroup().location

@description('Préfixe des ressources')
param prefix string = 'minio-demo'

@description('Image MinIO')
param image string = 'cgr.dev/chainguard/minio:latest'

@description('Utilisateur root MinIO')
param rootUser string = 'minioadmin'

@secure()
@description('Mot de passe root MinIO (8 caractères minimum)')
param rootPassword string

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${prefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource minio 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${prefix}-app'
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      // Accessible uniquement depuis l'environnement Container Apps
      ingress: {
        external: false
        targetPort: 9000
        transport: 'auto'
        additionalPortMappings: [
          {
            external: false
            targetPort: 9001
            exposedPort: 9001
          }
        ]
      }
      secrets: [
        { name: 'root-password', value: rootPassword }
      ]
    }
    template: {
      containers: [
        {
          name: 'minio'
          image: image
          args: [ 'server', '/data', '--console-address', ':9001' ]
          env: [
            { name: 'MINIO_ROOT_USER', value: rootUser }
            { name: 'MINIO_ROOT_PASSWORD', secretRef: 'root-password' }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          volumeMounts: [
            { volumeName: 'data', mountPath: '/data' }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/minio/health/live', port: 9000 }
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: { path: '/minio/health/ready', port: 9000 }
              periodSeconds: 15
            }
          ]
        }
      ]
      // Replica unique : MinIO standalone ne se scale pas horizontalement
      scale: { minReplicas: 1, maxReplicas: 1 }
      // Stockage éphémère : les données sont perdues au redémarrage
      volumes: [
        { name: 'data', storageType: 'EmptyDir' }
      ]
    }
  }
}

output fqdn string = minio.properties.configuration.ingress.fqdn
output environmentDefaultDomain string = env.properties.defaultDomain
