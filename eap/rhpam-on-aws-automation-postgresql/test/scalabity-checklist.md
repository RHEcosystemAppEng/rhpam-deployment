# Scalability checklist
The purpose is to have multiple servers all with the same deployments, to emulate the
actual environment defined by the CI/CD pipeline. The assumption is that servers remain
"immutable" after the initial deployment, so only process management is validated.

## Preliminary steps
- [ ] Launch a new Kie Server instance
    - [ ] The server is listed in the Business Central `Execution servers` page
- [ ] Deploy project from Business Central or REST API (VM in the same VPC)
    - The project contains one human task
    - The project contains `System.out.println` to monitor the execution
    - [ ] Validate all the servers have the same list of containers
## Scalability checklist
- [ ] Start some process instances
    - [ ] All the servers return the same list of active processes
- [ ] Complete the active processes
    - [ ] The list of active processes is updated
    - [ ] The process status is updated

Every test is validated from:
- [ ] Business Central
- [ ] Server REST API (VM in the same VPC)

For every server:
- [ ] Monitor `server.log` to verify that all the servers are used according to the
  Load Balancer policy

Repeat the checklist with the following updates:
- [ ] Terminate one of the servers
  - [ ] The other server handles the create/complete requests
  - [ ] No errors are expected
- [ ] Create a new server
  - [ ] The other server handles the create/complete requests
  - [ ] After some time the new servers starts to accept requests
  - [ ] No errors are expected
