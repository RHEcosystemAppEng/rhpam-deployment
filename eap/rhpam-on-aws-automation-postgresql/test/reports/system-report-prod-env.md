# System validation report for [prod-env]

## Kie server
Purpose is to validate the connectivity to Kie Server and from Kie server to Business Central, Keycloak
- [x] Check accessibility of Kie Server from browser
  - [x] Jboss answers on https://<KS-Host>
  - [x] Kie Server answers on https://<KS-Host>/kie-server/services/rest/server/containers
  - **Note**: using load balancer host instead of server IP
- [x] Check authentication through Keycloak
  - [x] In incognito browser browse to https://<KS-Host>/kie-server/services/rest/server/containers
  - [x] In Postman Get request https://<KS-Host>/kie-server/services/rest/server/containers

## Keycloak
Purpose is to validate the connectivity to Keycloak
- [x] Check accessibility of Keycloak console from browser
  - [x] https://<Keycloak-Host>/auth
  - [x] `rhpam-prod` realm is configured

 
