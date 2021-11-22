## Create the KIE Server image
**Prerequisites**: power down the KIE Server VM first

Customize the following instructions with your actual parameters before running them:
Gallery creation for resource group (command 2) can be skipped if exists

```shell
az login

az sig create --resource-group <RESOURCE_GROUP> --gallery-name <NEW_GALLERY_NAME>

az sig image-definition create \
   --resource-group <RESOURCE_GROUP> \
   --gallery-name <NEW_GALLERY_NAME> \
   --gallery-image-definition kie-server-template-definition \
   --hyper-v-generation V2 \
   --publisher <NEW_PUBLISHER> \
   --offer <NEW_OFFER> \
   --sku <NEW_SKU> \
   --os-type Linux \
   --os-state specialized

az sig image-version create \
   --resource-group <RESOURCE_GROUP> \
   --gallery-name <NEW_GALLERY_NAME> \
   --gallery-image-definition kie-server-template-definition \
   --gallery-image-version 1.0.0 \
   --target-regions "<KIE_SERVER_REGION>" \
   --managed-image "<KIE_SERVER_VM_ID"
```

## Create the VM Scale Set and the Azure Load Balancer
[only for Runtime environment]
If you want to create the resources for the Runtime environment, execute the following to deploy the VM Scale Set and 
the Azure Load Balancer: 
```shell
az vmss create \
   --resource-group <RESOURCE_GROUP> \
   --name <NEW_SCALE_SET_NAME> \
   --image "<NEW_KIE_SERVER_IMAGE_ID>" \
   --specialized

az network public-ip show \
  --resource-group <RESOURCE_GROUP> \
  --name <LOAD_BALANCER_IP_ADDRESS> \
  --query \[ipAddress\] \
  --output tsv
=>52.152.178.161

az network lb rule create \
  --resource-group <RESOURCE_GROUP> \
  --name <NEEW_LOAD_BALANCER_RULE_NAME> \
  --lb-name <LOAD_BALANCER_IP_NAME> \
  --backend-pool-name <LOAD_BALANCER_POOL_NAME> \
  --backend-port 8080 \
  --frontend-ip-name <LOAD_BALANCER_FRONT_END_NAME> \
  --frontend-port 8080 \
  --protocol tcp
```

Note: after the setup is configured, you should also define a DNS name for the newly created Load Balancer IP address.
