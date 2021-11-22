## Create the Business Central image
**Prerequisites**: power down the Business Central VM first

Customize the following instructions with your actual parameters before running them.
Gallery creation for resource group (command 2) can be skipped if exists 

```shell
az login

az sig create --resource-group <RESOURCE_GROUP> --gallery-name <NEW_GALLERY_NAME>

az sig image-definition create \
   --resource-group <RESOURCE_GROUP> \
   --gallery-name <NEW_GALLERY_NAME> \
   --gallery-image-definition smart-router-template-definition \
   --hyper-v-generation V2 \
   --publisher <NEW_PUBLISHER> \
   --offer <NEW_OFFER> \
   --sku <NEW_SKU> \
   --os-type Linux \
   --os-state specialized

az sig image-version create \
   --resource-group <RESOURCE_GROUP> \
   --gallery-name <NEW_GALLERY_NAME> \
   --gallery-image-definition smart-router-template-definition \
   --gallery-image-version 1.0.0 \
   --target-regions "<SMART_ROUTER_REGION>" \
   --managed-image "<SMART_ROUTER_VM_ID"
```