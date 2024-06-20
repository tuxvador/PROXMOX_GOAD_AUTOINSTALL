resource "local_file" "delete_pools_script" {
  content  = <<-EOT
    #!/bin/bash
    sleep 1
    pvesh delete /pools/${var.pools.admin_pool}
    pvesh delete /pools/${var.pools.template_pool}
    pvesh delete /pools/${var.pools.goad_pool}
  EOT
  filename = "${path.module}/delete_pools.sh"
}

resource "null_resource" "delete_pools" {
  provisioner "local-exec" {
    when    = destroy
    command = "bash ${self.triggers.delete_pools_script}"
  }

  triggers = {
    delete_pools_script = local_file.delete_pools_script.filename
  }
}
