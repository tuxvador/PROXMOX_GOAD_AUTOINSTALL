#!/bin/bash

apt-get update -y
apt-get install -y fish curl git ncdu vim tmux gnupg software-properties-common mkisofs jq
git clone "https://github.com/oh-my-fish/oh-my-fish.git" /tmp/oh-my-fish
fish -c "/tmp/oh-my-fish/bin/install --offline --noninteractive --yes"
chsh -s /usr/bin/fish

curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update -y && apt install packer

# Install the HashiCorp GPG key.
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

# add terraform sourcelist
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
tee /etc/apt/sources.list.d/hashicorp.list

# update apt and install terraform
apt update -y
apt install -y terraform
apt install -y ansible-core

mkdir -p /root/GIT
cd /root/GIT/
git clone https://github.com/Orange-Cyberdefense/GOAD.git

cd /root/GIT/GOAD/packer/proxmox/scripts/sysprep
wget https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi

cd /root/GIT/GOAD/packer/proxmox/
cp config.auto.pkrvars.hcl.template config.auto.pkrvars.hcl