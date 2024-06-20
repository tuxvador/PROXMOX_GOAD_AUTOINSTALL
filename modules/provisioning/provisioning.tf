resource "proxmox_lxc" "goad_provisioning" {
  target_node     = "windows-perso"
  arch            = "amd64"
  pool            = "ADMIN"
  start           = true
  ostemplate      = var.provisioning.template
  vmid            = var.provisioning.vmid
  hostname        = "PROVISIONING"
  memory          = 2048
  swap            = 1024
  cores           = 4
  password        = var.provisioning.root_password
  unprivileged    = true
  ssh_public_keys = file(var.provisioning.public_key)

  rootfs {
    storage = "local-lvm"
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr2"
    ip     = "dhcp"
    gw     = var.provisioning.gateway
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = "provisioning"
    private_key = file(var.provisioning.private_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    script = "modules/provisioning/scripts/post-install.sh"
  }

  provisioner "file" {
    source      = "files/config.auto.pkrvars.hcl"
    destination = "/root/GIT/GOAD/packer/proxmox/config.auto.pkrvars.hcl"
  }

  provisioner "remote-exec" {
    script = "modules/provisioning/scripts/packer-templating.sh"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.provisioning.private_key} root@provisioning:/root/GIT/GOAD/packer/proxmox/iso/scripts_withcloudinit.iso /var/lib/vz/template/iso/scripts_withcloudinit.iso"
  }


  provisioner "local-exec" {
    command = "wget -nc -O /var/lib/vz/template/iso/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso||true"
  }

  provisioner "local-exec" {
    command = "bash install/goad-provisioning.sh"
  }

  provisioner "file" {
    source      = "files/goad-provisioning.variables.tf"
    destination = "/root/GIT/GOAD/ad/GOAD/providers/proxmox/terraform/variables.tf"
  }

  provisioner "remote-exec" {
    script = "modules/provisioning/scripts/terraform.sh"
  }

  provisioner "local-exec" {
    command = "bash modules/provisioning/scripts/snapshot.sh"
  }
}

resource "null_resource" "delete_goad_vms" {
  provisioner "local-exec" {
    when    = destroy
    command = "bash modules/provisioning/scripts/destroy.sh"
  }
}
