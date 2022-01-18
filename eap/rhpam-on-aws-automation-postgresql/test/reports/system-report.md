# System checklist

## Remote git server
Purpose is to validate connectivity to git repo
- [x]  Setup an empty repository on the git server
```shell
[from git VM]
sudo su
su - git
cd /home/git/
mkdir <directory_name>  e.g. mkdir redhat.git
cd redhat.git
git init --bare
```
- [x] Add files from the Business Central VM
```shell
[from Business Central VM]
sudo su
cd /home/git_repositories
mkdir redhat && cd redhat
git init
echo "Initial commit" >> file.txt
git add .
git commit -m '<commit message>’
git remote add origin git@<GIT SERVER IP>:/home/git/redhat.git
git config pull.rebase false
git pull origin master --rebase
git push origin master
```
- [x] Clone and verify the changes
```shell
cd /home/git_repositories
rm -rf redhat
git clone git@<GIT SERVER IP>:/home/git/redhat.git
```
- [x] Update files
```shell
echo "Next commit" >> file.txt
git add .
git commit -m '<commit message>’
git push origin master
```
- [x] Repeat clone test and verify the changes

## EFS mount
Purpose is to validate availability of a persistent mount directory and existence of mount unit file
- [x] Check mount on Business Central  
```shell
[from Business Central VM]
# mount exists as mount unit file -> used in bc.service
systemctl list-unit-files -t mount | grep  <mount point>
# mount is active
systemctl status <mount point> | grep "active (mounted)"
```
- Troubleshoot
```shell
[from Business Central VM]
# mount not active:
# mount point is defined permanently
cat /etc/fstab | grep <mount point>
# mount point is defined at all
cat /proc/mounts | grep <mount point>
# mount not a unit file:
# reboot instance or reload system manager to create unit file, repeat above `Check mount on BC`
sudo systemctl daemon-reload
```
If another mount point should also exist on Kie server, repeat above check on that server

**Issues**:
*  ✅  [[Issue] mount point with hyphen copy problem](https://issues.redhat.com/browse/APPENG-223)


## Business Central
Purpose is to validate the connectivity to Business Central and from Business Central to Kie server, Keycloak 
- [x] Check accessibility of Business Central from browser
  - [x] Jboss answers on https://<BC-Host>
  - [x] Business Central answers on https://<BC-Host>/business-central
- [x] Check accessibility of Kie Server from Business Central VM
  - [x] Curl to Kie Server private ip
```shell
-L for following redirects, -k for self-signed certificates, -v for verbose

curl -vk --user username:password --header 'Content-Type: application/json' http://<KS-private-ip>:8080/kie-server/services/rest/server/containers
curl -vk --user username:password --header 'Content-Type: application/json' https://<KS-private-ip>:8443/kie-server/services/rest/server/containers
```

- TroubleShoot
```shell
[from Business Central VM]
# Business Central not accessible from browser - accessible locally:
curl -vL --user "username:password" http://<BC-private-ip>:8080/business-central
curl -kvL --user "username:password" https://<BC-private-ip>:8443/business-central
# service is active
echo $(systemctl status bc.service | grep "active"
# monitor logs
<rhpam_home>/standalone/logs/server.log
```

## Kie server
Purpose is to validate the connectivity to Kie Server and from Kie server to Business Central, Keycloak
- [x] Check accessibility of Kie Server from browser
  - [x] Jboss answers on https://<KS-Host>
  - [x] Kie Server answers on https://<KS-Host>/kie-server/services/rest/server/containers
- [x] Check accessibility of Business Central from Kie Server VM
  - [x] Curl to Business Central Controller through ALB
```shell
-L for following redirects, -k for self-signed certificates, -v for verbose
curl -kv --user username:password --header 'Content-Type: application/json' https://<BC-Host>/business-central/rest/controller/management/servers
```
- [x] Check authentication through Keycloak
  - [x] In inkognito browser browse to https://<KS-Host>/kie-server/services/rest/server/containers
  - [x] In Postman Get request https://<KS-Host>/kie-server/services/rest/server/containers

- TroubleShoot
```shell
[from Kie Server VM]
# Kie server not accessible from browser - accessible locally:
curl -v --user "username:password" "http://<KS-private-ip>:8080/kie-server/services/rest/server/containers" -H "accept: application/json"
curl -vk --user "username:password" "https://<KS-private-ip>:8443/kie-server/services/rest/server/containers" -H "accept: application/json"
# service is active
echo $(systemctl status ks.service | grep "active"
# monitor logs
<rhpam_home>/standalone/logs/server.log

[from Business Central VM]
# Business Central Controller not accessible from Kie Server - accessible locally:
curl -v --user "username:password" --header 'Content-Type: application/json' http://<BC-private-ip>:8080/business-central/rest/controller/management/servers
curl -vk --user "username:password" --header 'Content-Type: application/json' https://<BC-private-ip>:8443/business-central/rest/controller/management/servers
```

## Keycloak
Purpose is to validate the connectivity to Keycloak
- [x] Check accessibility of Keycloak console from browser
  - [x] https://<Keycloak-Host>/auth

 
