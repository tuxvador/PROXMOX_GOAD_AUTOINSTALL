#!/bin/bash

# Define the pool ID and node name
POOL_ID="GOAD"
NODE_NAME="windows-perso"

# Get the list of VM IDs in the pool
VM_IDS=$(pvesh get /pools/${POOL_ID} --output-format json | jq -r '.members[] | select(.type == "qemu") | .vmid')

# Loop through each VM ID, stop the VM, and then destroy it
for VMID in $VM_IDS; do
  echo "Stopping VM ID: $VMID"
  pvesh create /nodes/${NODE_NAME}/qemu/${VMID}/status/stop
  
  echo "Destroying VM ID: $VMID"
  pvesh delete /nodes/${NODE_NAME}/qemu/${VMID}
done

echo "All VMs in the pool ${POOL_ID} have been stopped and destroyed."