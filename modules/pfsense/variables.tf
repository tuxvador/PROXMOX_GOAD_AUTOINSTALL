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
