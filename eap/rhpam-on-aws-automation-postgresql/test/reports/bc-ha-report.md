# High availability validation report for Business Central
The purpose is to verify that, whenever an active Business Process crashes, it is replaced by 
a new instance managed by the same Application Load Balancer and that the status of all the authored projects
is not affected by the VM replacement.

- [x] Setup the auto-scaling-group for the Business Central instance (capacity max: 1 instance)
  - Configure public IP in every new instance to simplify the networking connections 
- [x] Setup the application load balancer for the auto-scaling-group (HTTP only)
  - [x] The business central console is accessible through the application load balancer
- [x] Terminate the Business Central instance
    - [x] New Business Central instance is launched
- [x] Open the Business Central console (using Load Balancer hostname)
    - [x] The previous projects are displayed
    - [x] Apply some changes and then terminate the Business Central instance
    - [x] New Business Central instance is launched
    - [x] The latest changes are displayed