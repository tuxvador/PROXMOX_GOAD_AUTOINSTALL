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
