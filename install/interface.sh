#!/bin/bash

wanmask=0
wannet=""

echo "Check interface names in /etc/network/interface before running this script"
echo "----------------------------------------------"
echo "Create static interfaces"
echo "----------------------------------------------"

cidr_to_netmask() {
    local cidr=$1
    if [[ $cidr -lt 1 || $cidr -gt 32 ]]; then
        echo "Invalid CIDR value. It must be between 1 and 32."
        return 1
    fi

    local mask=0xffffffff
    local shift=$((32 - cidr))
    mask=$((mask << shift))
    local octet1=$(( (mask & 0xff000000) >> 24 ))
    local octet2=$(( (mask & 0x00ff0000) >> 16 ))
    local octet3=$(( (mask & 0x0000ff00) >> 8 ))
    local octet4=$(( mask & 0x000000ff ))
    echo "$octet1.$octet2.$octet3.$octet4" > /tmp/mask
}

ifreload -a

#------------------------------------------------------------------
# Function to perform the installation
install_function() {
  echo "Running the interactive installation process..."
  interfaces=$(grep IFACENAME goad.conf | cut -d "=" -f2)
  # Loop through the values
  for interface in $interfaces; do
    echo "Processing interface: $interface"
    # Add your processing commands here
    name=$(echo $interface |cut -d '-' -f1)
    ip=$(echo $interface |cut -d '-' -f2)
    mask=$(echo $interface |cut -d '-' -f3)
    pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -address $ip -netmask $mask
  done

  vlan_interfaces=$(grep VLANIFACE goad.conf | cut -d "=" -f2)
  # Loop through the values
  for vlan_interface in $vlan_interfaces; do
    echo "Processing vlan_interface: $vlan_interface"
    # Add your processing commands here
    name=$(echo $vlan_interface |cut -d '-' -f1)
    ids=$(echo $vlan_interface |cut -d '-' -f2)
    pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -bridge_vlan_aware yes
    # Set the Internal Field Separator to a comma
    IFS=','

    # Convert the string into an array
    read -ra ADDR <<< "$ids"

    # Loop through the array
    for value in "${ADDR[@]}"; do
      echo "Processing value: $value"
      # Add your processing commands here
      pvesh create /nodes/windows-perso/network -iface "vlan"$value -type vlan -autostart true -vlan-raw-device $name
    done

    # Reset the IFS to its default value (whitespace)
    unset IFS
  done
  wanmask=$(grep WANMASK goad.conf | cut -d "=" -f2)
  wannet=$(grep WANNET goad.conf | cut -d "=" -f2)
}

# Extract the value of DEFAULT_INSTALL from goad.conf
default_install=$(grep DEFAULT_INSTALL goad.conf | cut -d "=" -f2 | tr -d '[:space:]')

# Check if default_install is set to Y and run the function if it is
if [ "$default_install" = "Y" ]; then
    install_function
else
    echo "DEFAULT_INSTALL is not set to Y. Proceeding with interactive install."
    while :; do
      read -p "Enter a number of interface you want to create between 2 and 5 (default 2): " if_number
      [[ ${if_number:=2} =~ ^[0-9]+$ ]] || { echo "input an integer between 1 and 5"; continue; }
      #echo $if_number
      if ((if_number >= 1 && if_number <= 5)); then
        break
      else
        echo "input an integer between 1 and 5"
      fi
    done

    for i in $(seq 1 $if_number); do
      while :; do
        if [[ $i -eq 1 ]];then
          read -p "Enter a valid ip adress number $i (defaults: 10.0.0.1): " ip
          [[ ${ip:=10.0.0.1} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo " Not a valid ip adress "; continue; }
        else
          read -p "Enter a valid ip adress number $i (defaults: 192.168.2.1): " ip
          [[ ${ip:=192.168.2.1} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo " Not a valid ip adress "; continue; }
        fi
        #echo $ip
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          break
        else
          echo " Not a valid ip adress"
        fi
      done

      while :; do
        netmask=''
        if [[ $i -eq 1 ]];then
          read -p "Enter network mask between 1 and 32 (default: 30): " mask
          [[ ${mask:=30} =~ ^[0-9]+$ ]] || { echo "input an integet between 1 and 32"; continue; }
        else
          read -p "Enter network mask between 1 and 32 (default: 24): " mask
          [[ ${mask:=24} =~ ^[0-9]+$ ]] || { echo "input an integet between 1 and 32"; continue; }
        fi
        #echo $mask
        if (($mask >= 1 && $mask <= 32)); then
        (cidr_to_netmask $mask)
          netmask=$(cat "/tmp/mask")
          break
        else
          echo "input an integet between 1 and 32"
        fi
      done

      name="vmbr"
      while :; do
        if [[ $i -eq 1 ]];then
          read -p "Enter the bridge name to create vmbr? (default: 1): " if_name
          [[ ${if_name:=1} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        else
          read -p "Enter the bridge name to create vmbr? (default: 2): " if_name
          [[ ${if_name:=2} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        fi
        #echo $if_name
        if ((if_name >= 1 && if_name <= 99)); then
          name="$name$if_name"
          #echo $name
          break
        else
          echo "Enter a number between 0 and 99"
        fi
      done
      #echo $if_number $ip $netmask $name
      pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -address $ip -netmask $netmask
    done

    echo "----------------------------------------------"
    echo "Create raw device for vlan"
    echo "----------------------------------------------"
    while :; do
        read -p "Enter the raw device vlan name vmbr? (default:3): " vlanvmbr
        [[ ${vlanvmbr:=3} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        #echo $vlanvmbr
        if ((vlanvmbr >= 1 && vlanvmbr <= 99)); then
          name="$vlanvmbr"
          #echo $name
          break
        else
          echo "Enter a number between 0 and 99"
        fi
    done
    pvesh create /nodes/windows-perso/network -iface "vmbr"$name -type bridge -autostart true -bridge_vlan_aware yes

    echo "----------------------------------------------"
    echo "Create linux vlans devices for each vlan"
    echo "----------------------------------------------"
    while :; do
      read -p "Enter a number of vlans you wish to create (default:2): " if_vlan
      [[ ${if_vlan:=2} =~ ^[0-9]+$ ]] || { echo "input an integet between 1 and 5"; continue; }
      #echo $if_vlan
      if ((if_vlan >= 1 && if_number <= 5)); then
        break
      else
        echo "input an integer between 1 and 5"
      fi
    done

    for i in $(seq 1 $if_vlan); do
      while :; do
        if [[ $i -eq 1 ]];then
          read -p "Enter a number corresponding to the vlan id (defaults: 10): " if_vlanid
          [[ ${if_vlanid:=10} =~ ^[0-9]+$ ]] || { echo "input an integer"; continue; }
        else
          read -p "Enter a number corresponding to the vlan id (defaults: 20): " if_vlanid
          [[ ${if_vlanid:=20} =~ ^[0-9]+$ ]] || { echo "input an integer"; continue; }
        fi
        #echo $if_vlanid
        break
      done
      pvesh create /nodes/windows-perso/network -iface vlan$if_vlanid -type vlan -autostart true -vlan-raw-device "vmbr"$vlanvmbr
    done

    echo "----------------------------------------------"
    echo "Enter pfsense Wan Network and mask"
    echo "----------------------------------------------"
    while :; do
      read -p "Enter the wan network used by pfsense (default:10.0.0.0): " wannet #variable used to add post up and down rules to proxmox ($wannet and $wanmask)
      [[ ${wannet:=10.0.0.0} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo " Not a valid ip adress "; continue; }
      #echo $wannet
      if [[ $wannet =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
      else
        echo " Not a valid ip adress"
      fi
    done

    while :; do
      read -p "Enter wan network mask between 1 and 32 (default:30): " wanmask
      [[ ${wanmask:=30} =~ ^[0-9]+$ ]] || { echo "input an integet between 1 and 32"; continue; }
      #echo $wanmask
      if (($wanmask >= 1 && $wanmask <= 32)); then
        break
      else
        echo "input an integet between 1 and 32"
      fi
    done
fi
#------------------------------------------------------------------

cp /etc/network/interfaces.new /etc/network/interfaces
rm /etc/network/interfaces.new
ifreload -a

echo "----------------------------------------------"
echo "configure interfaces in pfsense terraform file"
echo "----------------------------------------------"
cp modules/pfsense/pfsense.tf.template modules/pfsense/pfsense.tf

# Extract the interface name from goad.conf
WANIFACE=$(grep WAN-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')
LANIFACE=$(grep LAN-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')
VLANIFACE=$(grep Vlan-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')

# Use sed to replace placeholders in your configuration
sed -i -e "s|change-to-lan-interface1|${WANIFACE}|g" \
       -e "s|change-to-lan-interface2|${LANIFACE}|g" \
       -e "s|change-to-vlan-interface1|${VLANIFACE}|g" modules/pfsense/pfsense.tf

echo "----------------------------------------------"
echo "Enable port forwarding and forward all traffic to pfsense"
echo "----------------------------------------------"

vmbr0ip=$(ip addr show vmbr0 | grep "inet " |cut -d ' ' -f 6|cut -d/ -f 1)
pfswanip=$(grep 'PFS_WAN_IPV4_ADDRESS' goad.conf | cut -d'=' -f2)

awk -v wannet="$wannet" -v wanmask="$wanmask" -v vmbr0ip="$vmbr0ip" -v pfswanip="$pfswanip" '
/^auto vmbr0$/ { print; in_vmbr0=1; next }
in_vmbr0 && /^auto/ {
    in_vmbr0=0
    print "        #---- Enable ip forwarding"
    print "        post-up echo 1 > /proc/sys/net/ipv4/ip_forward"
    print "        post-down echo 0 > /proc/sys/net/ipv4/ip_forward"
    print ""
    print "        #---- allow ssh access without passing through pfsense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
    print ""
    print "        #---- allow https access without passing through pfsense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
    print ""
    print "        #---- add static route"
    print "        post-up ip route add 192.168.10.0/24 via 10.0.0.2"
    print "        post-down ip route del 192.168.10.0/24 via 10.0.0.2"
    print ""
    print "        #---- redirect all to pfsense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -j DNAT --to " pfswanip
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -j DNAT --to " pfswanip
    print ""
    print "        #---- add SNAT WAN -> public ip"
    print "        post-up iptables -t nat -A POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
    print "        post-down iptables -t nat -D POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
    print ""
    print "        #---- Exit network with vmbr0 ip address for all machines"
    print "        # post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
    print "        # post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
    print ""
}
{ print }
END {
    if (in_vmbr0) {
        print "        #---- Enable ip forwarding"
        print "        post-up echo 1 > /proc/sys/net/ipv4/ip_forward"
        print "        post-down echo 0 > /proc/sys/net/ipv4/ip_forward"
        print ""
        print "        #---- allow ssh access without passing through pfsense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
        print ""
        print "        #---- allow https access without passing through pfsense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
        print ""
        print "        #---- add static route"
        print "        post-up ip route add 192.168.10.0/24 via 10.0.0.2"
        print "        post-down ip route del 192.168.10.0/24 via 10.0.0.2"
        print ""
        print "        #---- redirect all to pfsense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -j DNAT --to " pfswanip
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -j DNAT --to " pfswanip
        print ""
        print "        #---- add SNAT WAN -> public ip"
        print "        post-up iptables -t nat -A POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
        print "        post-down iptables -t nat -D POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
        print ""
        print "        #---- Exit network with vmbr0 ip address for all machines"
        print "        # post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
        print "        # post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
        print ""
    }
}
' /etc/network/interfaces > temp_file && mv temp_file /etc/network/interfaces

ifreload -a

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf &> /dev/null

service networking restart

#---- Exit network with vmbr0 ip address for all machines"
# post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE
# post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE
