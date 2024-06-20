variable "pm_api" {
  type = object({
    url          = string
    token_id     = string
    token_secret = string
  })
  default = {
    url          = ""
    token_id     = ""
    token_secret = ""

  }
}

variable "pools" {
  type = object({
    admin_pool    = string
    template_pool = string
    goad_pool     = string
  })
  default = {
    template_pool = ""
    goad_pool     = ""
    admin_pool    = ""
  }
}


variable "pfsense" {
  type = object({
    password     = string
    new_password = string
    ip           = string
    vmid         = number
    iso          = string
  })
  default = {
    password     = ""
    new_password = ""
    ip           = ""
    vmid         = 0
    iso          = ""
  }
}

variable "provisioning" {
  type = object({
    vmid          = number
    disk_size     = string
    template      = string
    host          = string
    gateway       = string
    private_key   = string
    public_key    = string
    root_password = string
    vlanid        = number
  })
  default = {
    vmid          = 0
    disk_size     = ""
    template      = ""
    host          = ""
    gateway       = ""
    private_key   = ""
    public_key    = ""
    root_password = ""
    vlanid        = 0
  }
}

