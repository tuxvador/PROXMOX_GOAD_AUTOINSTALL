resource "null_resource" "create_admin_pool" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "pvesh create /pools --poolid ${var.pools.admin_pool} --comment create_admin_pool_for_pfsense;sleep 3"
  }
}

resource "null_resource" "create_template_pool" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "pvesh create /pools --poolid ${var.pools.template_pool} --comment create_template_pool_for_goad;sleep 3"
  }
}

resource "null_resource" "create_goad_pool" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "pvesh create /pools --poolid ${var.pools.goad_pool} --comment create_goad_pool_for_goad;sleep 3"
  }
}
