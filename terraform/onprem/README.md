# Bootstrapping Garage

In order to use Garage, we need to assign a layout:

```bash
# Show nodes
garage status

# Use node ID to assign layout
garage layout assign -z dc1 -c 10G [NODE_ID]
garage layout apply --version 1
```
