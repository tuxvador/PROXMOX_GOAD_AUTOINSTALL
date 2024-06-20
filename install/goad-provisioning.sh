#!/bin/bash

# Extract values from goad.conf
PROXM_API_URL=$(grep PROXM_API_URL goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
PROXM_TRF_TOKEN_ID=$(grep PROXM_TRF_TOKEN_ID goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
PROXM_TRF_TOKEN_VALUE=$(grep PROXM_TRF_TOKEN_VALUE goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
PROXM_NODE_NAME=$(grep PROXM_NODE_NAME goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
PROXMOX_GOAD_POOL=$(grep PROXMOX_GOAD_POOL goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
PROXM_VM_STORAGE=$(grep PROXM_VM_STORAGE goad.conf | cut -d '=' -f2 | tr -d '[:space:]')

# Get template IDs
WIN_SERVER_2019_ID=$(pvesh get /cluster/resources --output-format text --noborder 1 --type vm | grep WinServer2019x64 | cut -d ' ' -f1 | cut -d '/' -f2)
WIN_SERVER_2016_ID=$(pvesh get /cluster/resources --output-format text --noborder 1 --type vm | grep WinServer2016 | cut -d ' ' -f1 | cut -d '/' -f2)
# Uncomment the next line if you use Windows 10 template
# WINDOWS_10_ID=$(pvesh get /cluster/resources --output-format text --noborder 1 --type vm | grep Windows10 | cut -d ' ' -f1 | cut -d '/' -f2)

# Create the goad-provisioning.variables.tf file
cat > files/goad-provisioning.variables.tf << EOF
variable "pm_api_url" {
  default = "$PROXM_API_URL"
}

variable "pm_api_token" {
  default = "$PROXM_TRF_TOKEN_ID=$PROXM_TRF_TOKEN_VALUE"
}

variable "pm_node" {
  default = "$PROXM_NODE_NAME"
}

variable "pm_pool" {
  default = "$PROXMOX_GOAD_POOL"
}

variable "pm_full_clone" {
  default = false
}

# change this value with the id of your templates (win10 can be ignored if not used)
variable "vm_template_id" {
  type = map(number)

  # set the ids according to your templates
  default = {
      "WinServer2019_x64"  = $WIN_SERVER_2019_ID
      "WinServer2016_x64"  = $WIN_SERVER_2016_ID
      #"Windows10_22h2_x64" = $WINDOWS_10_ID
  }
}

variable "storage" {
  # change this with the name of the storage you use
  default = "$PROXM_VM_STORAGE"
}

variable "network_bridge" {
  default = "vmbr3"
}

variable "network_model" {
  default = "e1000"
}

variable "network_vlan" {
  default = 10
}
EOF