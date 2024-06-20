#!/bin/bash

ssh-keygen -f "/root/.ssh/known_hosts" -R "provisioning"
ssh-keygen -f "/root/.ssh/known_hosts" -R "10.0.0.2"
ssh-keygen -f "/root/.ssh/known_hosts" -R "192.168.2.2"

cp /etc/network/interfaces.back /etc/network/interfaces
service networking restart
ifreload -a

#terraform destroy -var-file="files/dev.tfvars" --auto-approve

pveum user delete terraform@pve && pveum role delete TerraformProv

### destroy all vms in goad pool
bash modules/provisioning/scripts/destroy.sh

### destroy pfsense and provisionning
qm stop 100 && qm destroy 100 
pct stop 101 && pct destroy 101