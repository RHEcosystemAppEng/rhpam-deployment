# High availability validation report for Kie Server
The purpose is to verify that, whenever an active Kie Server crashes, it is replaced by 
a new instance managed by the same Application Load Balancer and that the status of all deployed projects
is not affected by the VM replacement.

- [x] Setup the auto-scaling-group for the Kie Server instance (capacity max: 1 instance)
  - Configure public IP in every new instance to simplify the networking connections
- [x] Setup the application load balancer for the auto-scaling-group (HTTP only)
  - [x] The kie server is accessible through the application load balancer
- [ ] Terminate the Kie server instance
  - [x] New Kie server instance is launched and starts up successfully
  - [x] without user-data: just server registers itself successfully on BC Controller [only dev]
  - [x] with user-data: server registers itself and containers successfully on BC Controller [only dev]
  - [ ] Terminated Kie server is removed from BC GUI [only dev]
  
* ✅  [[Issue] Error on creation of process instance](https://issues.redhat.com/browse/APPENG-278)
* [[Issue] Terminated server not removed from BC](https://issues.redhat.com/browse/APPENG-280)

