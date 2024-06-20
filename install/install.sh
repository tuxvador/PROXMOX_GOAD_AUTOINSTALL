#!/bin/bash

# Check if the configuration file exists
if [ ! -f goad.conf ]; then
    echo "Configuration file 'goad.conf' not found!"
    exit 1
fi

if [ ! -f modules/pfsense/scripts/ansible/inventory.yml ]; then
    echo "Inventory file 'inventory.yml' not found!"
    exit 1
fi

cp /etc/network/interfaces /etc/network/interfaces.back

echo "********************************************************************************************"
echo "Create config"
echo "********************************************************************************************"
pmurl=$(echo 'PROXM_API_URL=https://'$(ip addr show vmbr0 | grep 'inet ' |cut -d ' ' -f 6|cut -d/ -f 1)':8006/api2/json');sed -i "s#PROXM_API_URL=.*#$pmurl#g" goad.conf
pfpwd=$(grep PFS_PWD goad.conf| cut -d "=" -f2)
pfpwdhash=$(htpasswd -bnBC 10 '' $pfpwd|head -n 1|cut -d ':' -f2)
prov_passwd=$(pwgen -c 16 -n 1)
#********** generate ssh keys for provisioning
echo -e 'y\n' | ssh-keygen -q -t rsa -b 4096 -N "" -f ssh/provisioning_id_rsa
echo -e 'y\n' | ssh-keygen -q -t rsa -b 4096 -N "" -f ssh/pfsense_id_rsa
echo

# ##### Download pfsense
wget -nc -O /var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz wget https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz
gzip -d pfSense-CE-2.7.2-RELEASE-amd64.iso.gz

# Extract the pfSense ISO filename
pfs_iso=$(ls /var/lib/vz/template/iso/ | grep -i pfsense|grep -v gz)

sed -i "s|.*PFS_HASH=.*|PFS_HASH=$pfpwdhash|g" goad.conf
sed -i "s|.*PROV_PASSWORD=.*|PROV_PASSWORD=$prov_passwd|g" goad.conf
sed -i "s|.*PFS_ISO=.*|PFS_ISO=local:iso/$pfs_iso|" goad.conf

echo "********************************************************************************************"
echo "create Terraform user, terraform role and api access token"
echo "********************************************************************************************"
trf_user=$(grep PROXM_TRF_USER goad.conf| cut -d "=" -f2)
trf_usr_pwd=$(grep PROXM_TRF_USR_PWD goad.conf| cut -d "=" -f2)
trf_token_id=$(grep PROXM_TRF_TOKEN_ID goad.conf| cut -d "=" -f2)
trf_token_name=$(grep PROXM_TRF_TOKEN_NAME goad.conf| cut -d "=" -f2)

pveum user add $trf_user@pve --password $trf_usr_pwd
trf_token_value=$(pvesh create /access/users/terraform@pve/token/$trf_token_name --expire 0 --privsep 0 --output-format json | cut -d ',' -f4|cut -d '"' -f4)

#Terraform password generation
sed -i "s#.*PROXM_TRF_USR_PWD=.*#PROXM_TRF_USR_PWD=$(pwgen -c 16 -n 1)#g" goad.conf
#Token creation
sed -i "s#.*PROXM_TRF_TOKEN_VALUE=.*#PROXM_TRF_TOKEN_VALUE=$trf_token_value#g" goad.conf

trf_role=$(grep PROXM_TRF_ROLE goad.conf| cut -d "=" -f2)


pveum role add $trf_role -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt VM.Console SDN.Use"
pveum aclmod / -user $trf_user@pve -role $trf_role

echo "********************************************************************************************"
echo "generate tfvarfile"
echo "********************************************************************************************"
cat > files/dev.tfvars << EOF
pm_api = {
  url          = "$(grep PROXM_API_URL goad.conf | cut -d '=' -f2)"
  token_id     = "$(grep PROXM_TRF_TOKEN_ID goad.conf | cut -d '=' -f2)"
  token_secret = "$(grep PROXM_TRF_TOKEN_VALUE goad.conf | cut -d '=' -f2)"
}

pools = {
  admin_pool      = "$(grep PROXM_ADMIN_POOL goad.conf | cut -d '=' -f2)"
  template_pool   = "$(grep PROXM_TEMPLATE_POOL goad.conf | cut -d '=' -f2)"
  goad_pool       = "$(grep PROXMOX_GOAD_POOL goad.conf | cut -d '=' -f2)"
}

pfsense = {
  password     = "$(grep PFS_DEFAULT_PWD goad.conf | cut -d '=' -f2)"
  new_password = "$(grep PFS_PWD goad.conf | cut -d '=' -f2)"
  ip           = "$(grep PFS_LAN_IP goad.conf | cut -d '=' -f2)"
  vmid         = "$(grep PROXM_VMID goad.conf | cut -d '=' -f2)"
  iso          = "$(grep PFS_ISO goad.conf | cut -d '=' -f2)"
}

provisioning = {
  vmid          = "$(grep PROV_VMID goad.conf | cut -d '=' -f2)"
  disk_size     = "$(grep PROV_DISK_SIZE goad.conf | cut -d '=' -f2)"
  template      = "$(grep PROV_TEMPLATE goad.conf | cut -d '=' -f2)"
  host          = "$(grep PROV_HOSTS goad.conf | cut -d '=' -f2)"
  gateway       = "$(grep PROV_GATEWAY goad.conf | cut -d '=' -f2)"
  private_key   = "$(grep PROV_SSH_KEY goad.conf | cut -d '=' -f2)"
  public_key    = "$(grep PROV_SSH_PUB_KEY goad.conf | cut -d '=' -f2)"
  root_password = "$(grep PROV_PASSWORD goad.conf | cut -d '=' -f2)"
  vlanid       = "$(grep PROV_VLANID goad.conf | cut -d '=' -f2)"
}
EOF

# create file needed by packer

cat > files/config.auto.pkrvars.hcl << EOF
proxmox_url             = "$(grep PROXM_API_URL goad.conf | cut -d '=' -f2)"
proxmox_username        = "$(grep PROXM_TRF_TOKEN_ID goad.conf | cut -d '=' -f2)"
proxmox_token           = "$(grep PROXM_TRF_TOKEN_VALUE goad.conf | cut -d '=' -f2)"
proxmox_skip_tls_verify = "true"
proxmox_node            = "$(grep PROXM_NODE_NAME goad.conf | cut -d '=' -f2)"
proxmox_pool            = "$(grep PROXM_TEMPLATE_POOL goad.conf | cut -d '=' -f2)"
proxmox_iso_storage         = "$(grep PROXM_ISO_STORAGE goad.conf | cut -d '=' -f2)"
proxmox_vm_storage         = "$(grep PROXM_VM_STORAGE goad.conf | cut -d '=' -f2)"
EOF

echo ''
echo ''

echo "********************************************************************************************"
echo "create certs"
echo "********************************************************************************************"

bash install/certs.sh

echo ''
echo ''

echo "********************************************************************************************"
echo "Install needed packages"
echo "********************************************************************************************"

bash install/dependencies.sh

echo ''
echo ''

echo "********************************************************************************************"
echo "create interfaces"
echo "********************************************************************************************"

bash install/interface.sh

echo ''
echo ''

echo "*******************************************************"
echo "repalce values in ansible inventory with values from goad.conf"
echo "*******************************************************"
# Extract values from goad.conf
PFS_LAN_IP=$(grep 'PFS_LAN_IPV4_ADDRESS' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_DEFAULT_PWD=$(grep 'PFS_DEFAULT_PWD' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_PWD=$(grep 'PFS_PWD' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_HASH=$(grep 'PFS_HASH' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_IP=$(grep 'PFS_WAN_IPV4_ADDRESS' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PROXM_DOMAIN=$(grep 'PROXM_DOMAIN' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_HOSTNAME=$(grep 'PFS_HOSTNAME' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PROXM_DNS_HOSTNAME=$(grep 'PROXM_DNS_HOSTNAME' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PROXM_DNS_IP=$(grep 'PROXM_DNS_IP' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_whitelist_ssh_network=$(grep 'PFS_whitelist_ssh_network' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_NETWORK=$(grep 'PFS_WAN_NETWORK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_MASK=$(grep 'PFS_WAN_MASK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_LAN_NETWORK=$(grep 'PFS_LAN_NETWORK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_LAN_MASK=$(grep 'PFS_LAN_MASK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_INTERFACE=$(grep 'PFS_WAN_INTERFACE' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_LAN_INTERFACE=$(grep 'PFS_LAN_INTERFACE' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_OPTIONAL_INTERFACE=$(grep 'PFS_OPTIONAL_INTERFACE' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_VLAN10_INTERFACE=$(grep 'PFS_VLAN10_INTERFACE' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_VLAN20_INTERFACE=$(grep 'PFS_VLAN20_INTERFACE' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_IPV4_ADDRESS=$(grep 'PFS_WAN_IPV4_ADDRESS' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_WAN_GATEWAY=$(grep 'PFS_WAN_GATEWAY' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_LAN_IPV4_ADDRESS=$(grep 'PFS_LAN_IPV4_ADDRESS' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
PFS_LAN_GATEWAY=$(grep 'PFS_LAN_GATEWAY' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN10_NETWORK=$(grep 'VLAN10_NETWORK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN20_NETWORK=$(grep 'VLAN20_NETWORK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLANTAG10NAME=$(grep 'VLANTAG10NAME' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLANTAG10_ipv4=$(grep 'VLANTAG10_ipv4' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLANTAG20NAME=$(grep 'VLANTAG20NAME' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLANTAG20_ipv4=$(grep 'VLANTAG20_ipv4' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN10_DHCP_START=$(grep 'VLAN10_DHCP_START' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN10_DHCP_END=$(grep 'VLAN10_DHCP_END' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN20_DHCP_START=$(grep 'VLAN20_DHCP_START' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN20_DHCP_END=$(grep 'VLAN20_DHCP_END' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN10_ID=$(grep 'VLAN10_ID' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN20_ID=$(grep 'VLAN20_ID' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN10_DESC=$(grep 'VLAN10_DESC' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
VLAN20_DESC=$(grep 'VLAN20_DESC' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
GOAD_VPN_NETWORK=$(grep 'GOAD_VPN_NETWORK' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')
GOAD_VPN_PORT=$(grep 'GOAD_VPN_PORT' goad.conf | cut -d'=' -f2 | tr -d '[:space:]')

# Escape values for sed
escape_for_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

# Replace values in modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|ansible_host: .*|ansible_host: $(escape_for_sed "$PFS_LAN_IP")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(ansible_password:\s*\).*|\1$(escape_for_sed "$PFS_DEFAULT_PWD")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(new_pfs_pwd:\s*\).*|\1$(escape_for_sed "$PFS_PWD")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(new_pfs_pwd_hash:\s*\).*|\1$(escape_for_sed "$PFS_HASH")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_WAN_IP:\s*\).*|\1$(escape_for_sed "$PFS_WAN_IP")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PM_DOMAIN:\s*\).*|\1$(escape_for_sed "$PROXM_DOMAIN")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_HOSTNAME:\s*\).*|\1$(escape_for_sed "$PFS_HOSTNAME")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PM_DNS_HOSTNAME:\s*\).*|\1$(escape_for_sed "$PROXM_DNS_HOSTNAME")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PM_DNS_IP:\s*\).*|\1$(escape_for_sed "$PROXM_DNS_IP")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(whitelist_ssh_network:\s*\).*|\1$(escape_for_sed "$PFS_whitelist_ssh_network")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(WAN_NETWORK:\s*\).*|\1$(escape_for_sed "$PFS_WAN_NETWORK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(WAN_MASK:\s*\).*|\1$(escape_for_sed "$PFS_WAN_MASK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(LAN_NETWORK:\s*\).*|\1$(escape_for_sed "$PFS_LAN_NETWORK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(LAN_MASK:\s*\).*|\1$(escape_for_sed "$PFS_LAN_MASK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_WAN_INTERFACE:\s*\).*|\1$(escape_for_sed "$PFS_WAN_INTERFACE")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_LAN_INTERFACE:\s*\).*|\1$(escape_for_sed "$PFS_LAN_INTERFACE")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_OPTIONAL_INTERFACE:\s*\).*|\1$(escape_for_sed "$PFS_OPTIONAL_INTERFACE")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_VLAN10_INTERFACE:\s*\).*|\1$(escape_for_sed "$PFS_VLAN10_INTERFACE")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_VLAN20_INTERFACE:\s*\).*|\1$(escape_for_sed "$PFS_VLAN20_INTERFACE")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_WAN_IPV4_ADDRESS:\s*\).*|\1$(escape_for_sed "$PFS_WAN_IPV4_ADDRESS")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_WAN_GATEWAY:\s*\).*|\1$(escape_for_sed "$PFS_WAN_GATEWAY")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_LAN_IPV4_ADDRESS:\s*\).*|\1$(escape_for_sed "$PFS_LAN_IPV4_ADDRESS")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(PFS_LAN_GATEWAY:\s*\).*|\1$(escape_for_sed "$PFS_LAN_GATEWAY")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN10_NETWORK:\s*\).*|\1$(escape_for_sed "$VLAN10_NETWORK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN20_NETWORK:\s*\).*|\1$(escape_for_sed "$VLAN20_NETWORK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLANTAG10NAME:\s*\).*|\1$(escape_for_sed "$VLANTAG10NAME")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLANTAG10_ipv4:\s*\).*|\1$(escape_for_sed "$VLANTAG10_ipv4")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLANTAG20NAME:\s*\).*|\1$(escape_for_sed "$VLANTAG20NAME")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLANTAG20_ipv4:\s*\).*|\1$(escape_for_sed "$VLANTAG20_ipv4")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN10_DHCP_START:\s*\).*|\1$(escape_for_sed "$VLAN10_DHCP_START")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN10_DHCP_END:\s*\).*|\1$(escape_for_sed "$VLAN10_DHCP_END")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN20_DHCP_START:\s*\).*|\1$(escape_for_sed "$VLAN20_DHCP_START")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN20_DHCP_END:\s*\).*|\1$(escape_for_sed "$VLAN20_DHCP_END")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN10_ID:\s*\).*|\1$(escape_for_sed "$VLAN10_ID")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN20_ID:\s*\).*|\1$(escape_for_sed "$VLAN20_ID")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN10_DESC:\s*\).*|\1\"$(escape_for_sed "$VLAN10_DESC")\"|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(VLAN20_DESC:\s*\).*|\1\"$(escape_for_sed "$VLAN20_DESC")\"|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(GOAD_VPN_NETWORK:\s*\).*|\1$(escape_for_sed "$GOAD_VPN_NETWORK")|" modules/pfsense/scripts/ansible/inventory.yml
sed -i "s|\(GOAD_VPN_PORT:\s*\).*|\1$(escape_for_sed "$GOAD_VPN_PORT")|" modules/pfsense/scripts/ansible/inventory.yml

echo "********************************************************************************************"
echo "modify pfsense.sh with content from goad.conf"
echo "********************************************************************************************"

cp modules/pfsense/scripts/pfsense.template.sh modules/pfsense/scripts/pfsense.sh
chmod 755 modules/pfsense/scripts/pfsense.sh

# Read the WAN interface value from goad.conf
wan_interface_value=$(grep 'PFS_WAN_INTERFACE=' goad.conf | cut -d'=' -f2)
lan_interface_value=$(grep 'PFS_LAN_INTERFACE=' goad.conf | cut -d'=' -f2)
optional_interface_value=$(grep 'PFS_OPTIONAL_INTERFACE=' goad.conf | cut -d'=' -f2)
wan_ip_value=$(grep 'PFS_WAN_IPV4_ADDRESS=' goad.conf | cut -d'=' -f2)
wan_gateway_value=$(grep 'PFS_WAN_GATEWAY=' goad.conf | cut -d'=' -f2)
lan_ipv4_value=$(grep 'PFS_LAN_IPV4_ADDRESS=' goad.conf | cut -d'=' -f2)
lan_gateway_value=$(grep 'PFS_LAN_GATEWAY=' goad.conf | cut -d'=' -f2)
lan_dhcp_start_value=$(grep 'LAN_DHCP_START=' goad.conf | cut -d'=' -f2)
lan_dhcp_end_value=$(grep 'LAN_DHCP_END=' goad.conf | cut -d'=' -f2)

# Transform the WAN interface value to the desired format with dashes
transformed_wan_value=$(echo $wan_interface_value | sed 's/./&-/g' | sed 's/-$//')
transformed_lan_value=$(echo $lan_interface_value | sed 's/./&-/g' | sed 's/-$//')
transformed_optional_interface_value=$(echo $optional_interface_value | sed 's/./&-/g' | sed 's/-$//')
transformed_wan_ip_value=$(echo $wan_ip_value | sed 's/./&-/g' | sed 's/-$//')
transformed_wan_gateway_value=$(echo $wan_gateway_value | sed 's/./&-/g' | sed 's/-$//')
transformed_lan_ipv4_value=$(echo $lan_ipv4_value | sed 's/./&-/g' | sed 's/-$//')
transformed_lan_gateway_value=$(echo $lan_gateway_value | sed 's/./&-/g' | sed 's/-$//')
transformed_lan_dhcp_start_value=$(echo $lan_dhcp_start_value | sed 's/./&-/g' | sed 's/-$//')
transformed_lan_dhcp_end_value=$(echo $lan_dhcp_end_value | sed 's/./&-/g' | sed 's/-$//')

# Replace dots with "dot"
transformed_wan_ip_value=$(echo $transformed_wan_ip_value | sed 's/\./dot/g')
transformed_wan_gateway_value=$(echo $transformed_wan_gateway_value | sed 's/\./dot/g')
transformed_lan_ipv4_value=$(echo $transformed_lan_ipv4_value | sed 's/\./dot/g')
transformed_lan_gateway_value=$(echo $transformed_lan_gateway_value | sed 's/\./dot/g')
transformed_lan_dhcp_start_value=$(echo $transformed_lan_dhcp_start_value | sed 's/\./dot/g')
transformed_lan_dhcp_end_value=$(echo $transformed_lan_dhcp_end_value | sed 's/\./dot/g')


# Replace the WAN placeholder in modules/pfsense/scripts/pfsense.sh with the transformed WAN value
sed -i "s/chg_wan_interface/$transformed_wan_value/" modules/pfsense/scripts/pfsense.sh
# Replace the LAN placeholder in modules/pfsense/scripts/pfsense.sh with the transformed LAN value
sed -i "s/chg_lan_interface/$transformed_lan_value/" modules/pfsense/scripts/pfsense.sh
# Replace the OPTIONAL placeholder in modules/pfsense/scripts/pfsense.sh with the transformed OPTIONAL value
sed -i "s/chg_opt_interface/$transformed_optional_interface_value/" modules/pfsense/scripts/pfsense.sh
# Replace the WAN IP placeholder in modules/pfsense/scripts/pfsense.sh with the transformed WAN IP value
sed -i "s/change_pfs_wan_ip/$transformed_wan_ip_value/" modules/pfsense/scripts/pfsense.sh
# Replace the WAN Gateway placeholder in modules/pfsense/scripts/pfsense.sh with the transformed WAN Gateway value
sed -i "s/change_pfs_wan_gateway/$transformed_wan_gateway_value/" modules/pfsense/scripts/pfsense.sh
# Replace the LAN IPv4 placeholder in modules/pfsense/scripts/pfsense.sh with the transformed LAN IPv4 value
sed -i "s/change_pfs_lan_ip/$transformed_lan_ipv4_value/" modules/pfsense/scripts/pfsense.sh
# Replace the LAN Gateway placeholder in modules/pfsense/scripts/pfsense.sh with the transformed LAN Gateway value
sed -i "s/change_pfs_lan_gateway/$transformed_lan_gateway_value/" modules/pfsense/scripts/pfsense.sh
# Replace the VLAN2 DHCP start placeholder in modules/pfsense/scripts/pfsense.sh with the transformed VLAN2 DHCP start value
sed -i "s/change_pfs_lan_dhcp_start/$transformed_lan_dhcp_start_value/" modules/pfsense/scripts/pfsense.sh
# Replace the VLAN2 DHCP end placeholder in modules/pfsense/scripts/pfsense.sh with the transformed VLAN2 DHCP end value
sed -i "s/change_pfs_lan_dhcp_end/$transformed_lan_dhcp_end_value/" modules/pfsense/scripts/pfsense.sh

echo ''
echo ''

echo "********************************************************************************************"
echo "install and autoconfigure pfsense vm"
echo "********************************************************************************************"

terraform init
terraform apply -var-file="files/dev.tfvars" --auto-approve

echo ''
echo ''

echo "********************************************************************************************"
echo "Provisioning"
echo "********************************************************************************************"

echo ''
echo ''

echo "********************************************************************************************"
echo "delete terraform token, terraform user, terraform role"
echo "********************************************************************************************"
pvesh delete /access/users/$trf_user@pve/token/$trf_token_name
pveum user delete $trf_user@pve
pveum role delete $trf_role
