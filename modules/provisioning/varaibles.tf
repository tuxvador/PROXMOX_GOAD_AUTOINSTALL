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
  }
}
