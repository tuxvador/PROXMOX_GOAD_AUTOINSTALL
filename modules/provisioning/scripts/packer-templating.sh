#!/bin/bash

cd /root/GIT/GOAD/packer/proxmox/
./build_proxmox_iso.sh
sed -i 's/proxmox_password/proxmox_token/g' variables.pkr.hcl
sed -i 's/password\s*=\s*"\${var\.proxmox_password}"/token                = "${var.proxmox_token}"/g' packer.json.pkr.hcl
grep -rl 'vm_disk_format\s*=\cd /root/GIT/GOAD/packer/proxmox/s*"qcow2"' ./ | xargs sed -i 's/vm_disk_format\s*=\s*"qcow2"/vm_disk_format = "raw"/g'
grep -rl 'qcow2' ./ | xargs sed -i 's/qcow2/raw-lvm-thin/g'

sed -i '/variable "vm_name" {}/a variable "vm_id" {}' variables.pkr.hcl

# Array of vm_id values
vm_ids=(950 951 952 953 954)

# Counter for vm_id array
counter=0

# Loop through each windows*.pkvars.hcl file
for file in windows*.pkvars.hcl; do
    # Check if counter exceeds array length
    if [ $counter -ge ${#vm_ids[@]} ]; then
        echo "Not enough vm_id values for the number of files."
        exit 1
    fi
    # Debug: Print the current file and vm_id
    echo "Processing $file with vm_id ${vm_ids[$counter]}"
    # Use sed to insert vm_id after the vm_name line
    sed -i "/^vm_name\s*=.*/a vm_id               = ${vm_ids[$counter]}" "$file"

    # Increment the counter
    ((counter++))
done
#sed -i '/winrm_insecure       = true/i\  vm_id = "${var.vm_id}"' packer.json.pkr.hcl


# For LVM-THIN not supporting qcow2

# Adde Datastore.AllocateTemplate to terraform privs when created to be able to upload
packer init .
# Variables (you might want to pass these as arguments or environment variables)
get_hcl_value() {
  local key=$1
  local file=$2
  grep "${key}" "${file}" | sed 's/.*= "\(.*\)".*/\1/'
}

# Path to the configuration file
CONFIG_FILE="config.auto.pkrvars.hcl"

# Extract variables from the configuration file
PROXMOX_URL=$(get_hcl_value "proxmox_url" "${CONFIG_FILE}")
PROXMOX_USERNAME=$(get_hcl_value "proxmox_username" "${CONFIG_FILE}")
PROXMOX_TOKEN=$(get_hcl_value "proxmox_token" "${CONFIG_FILE}")
PROXMOX_NODE=$(get_hcl_value "proxmox_node" "${CONFIG_FILE}")
API_TOKEN_HEADER="PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}"

check_and_build() {
  local file=$1

  # Extract VM ID
  VM_ID=$(sed -n 's/.*vm_id *\= *\([0-9]*\).*/\1/p' "${file}")

  # Check if VM exists
  VM_EXISTS=$(curl -s -k -H "Authorization: ${API_TOKEN_HEADER}" \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID}" | jq '.data != null')

  # If VM exists, exit the script, otherwise proceed with the build
  if [ "$VM_EXISTS" = "true" ]; then
    echo "VM ${VM_ID} already exists. Skipping build."
  else
    echo "VM ${VM_ID} does not exist. Proceeding with build."
    packer validate -var-file="${file}"
    packer build -var-file="${file}" .
  fi
}

# Call the function with the file parameter
check_and_build "windows_server2019_proxmox_cloudinit.pkvars.hcl"
check_and_build "windows_server2016_proxmox_cloudinit.pkvars.hcl"
#check_and_build "windows_10_22h2_proxmox_cloudinit.pkvars.hcl"
