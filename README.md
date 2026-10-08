# MinIO sur Azure Container Apps (démo)

MinIO standalone (S3 compatible) sur ACA, ingress **interne** à l'environnement, stockage **éphémère** (EmptyDir : données perdues au redémarrage).

MinIO n'est pas un sidecar : c'est un serveur de stockage objet autonome.

## Déploiement

```powershell
az group create -n rg-minio-aca-demo -l francecentral
$pw = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 24 | % {[char]$_})
az deployment group create -g rg-minio-aca-demo -f main.bicep -p rootPassword=$pw
```

Sorties : `fqdn` (API S3 sur 443/9000, console sur le port 9001, internes à l'environnement).

## Notes

- Les images officielles `minio/minio` (Docker Hub, quay.io) ne sont plus accessibles : l'image par défaut est `cgr.dev/chainguard/minio:latest` (surchargeable via `-p image=...`). Épingler un tag/digest pour autre chose qu'une démo.
- Réplica unique (MinIO standalone ne scale pas horizontalement).
- Persistance : Azure Files NFS (environnement avec VNet) ; éviter SMB (MinIO attend du POSIX).
- Accès : depuis une autre app du même environnement (`https://<fqdn>`), ou `az containerapp exec` pour tester.
- Licence AGPLv3.

## Nettoyage

```powershell
az group delete -n rg-minio-aca-demo --yes
```
