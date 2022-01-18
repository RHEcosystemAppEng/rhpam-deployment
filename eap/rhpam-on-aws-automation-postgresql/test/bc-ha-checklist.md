# High availability checklist for Business Central
The purpose is to verify that, whenever an active Business Process crashes, it is replaced by 
a new instance managed by the same Application Load Balancer and that the status of all the authored projects
is not affected by the VM replacement.

- [ ] Setup the auto-scaling-group for the Business Central instance (capacity max: 1 instance)
  - Configure public IP in every new instance to simplify the networking connections
- [ ] Setup the application load balancer for the auto-scaling-group (HTTP only)
  - [ ] The business central console is accessible through the application load balancer
- [ ] Terminate the Business Central instance
    - [ ] New Business Central instance is launched
- [ ] Open the Business Central console (using Load Balancer hostname)
    - [ ] The previous projects are displayed
    - [ ] Apply some changes and then terminate the Business Central instance
    - [ ] New Business Central instance is launched
    - [ ] The latest changes are displayed
