#!/bin/bash

cd /root/GIT/GOAD/ad/GOAD/providers/proxmox/terraform
# Define the file to be modified
file="main.tf"  # Replace with your actual file name

# Use sed to replace the lines
sed -i '/username = var.pm_user/d' "$file"
sed -i '/password = var.pm_password/d' "$file"
sed -i '/insecure = true/i   api_token = var.pm_api_token' "$file"

sed -i '/^    name\s*=\s*string$/a\    vm_id = string' goad.tf
sed -i '/name\s*=\s*"GOAD-DC01"/a\ \ \ \ \ \ vm_id = 955' goad.tf
sed -i '/name\s*=\s*"GOAD-DC02"/a\ \ \ \ \ \ vm_id = 956' goad.tf
sed -i '/name\s*=\s*"GOAD-DC03"/a\ \ \ \ \ \ vm_id = 957' goad.tf
sed -i '/name\s*=\s*"GOAD-SRV02"/a\ \ \ \ \ \ vm_id = 958' goad.tf
sed -i '/name\s*=\s*"GOAD-SRV03"/a\ \ \ \ \ \ vm_id = 959' goad.tf

sed -i '/^\s*name\s*=\s*each\.value\.name/a\ \ \ \ vm_id = each.value.vm_id' goad.tf

terraform init
terraform plan -out goad.plan
terraform apply "goad.plan"

sleep 50

cd /root/GIT/GOAD/ansible
ansible-galaxy install -r requirements.yml
export ANSIBLE_COMMAND="ansible-playbook -i ../ad/GOAD/data/inventory -i ../ad/GOAD/providers/proxmox/inventory"
../scripts/provisionning.sh