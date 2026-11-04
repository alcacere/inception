# variables.pkr.hcl - Packer build variables

# --------------------------------------------------
# Debian ISO configuration
# --------------------------------------------------

variable "iso_url" {
  type        = string
  description = "URL of the Debian 13 netinst AMD64 ISO"
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum or URL to SHA256SUMS"
  default     = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
}

# --------------------------------------------------
# Virtual machine configuration
# --------------------------------------------------

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
  default     = "inception"
}

variable "login" {
  type        = string
  description = "Linux user created during installation"
  default     = "alcacere"
}

variable "cpus" {
  type        = number
  description = "Number of virtual CPUs"
  default     = 2
}

variable "memory" {
  type        = number
  description = "Amount of RAM in MB"
  default     = 4096
}

variable "disk_size" {
  type        = number
  description = "Virtual disk size in MB"
  default     = 20000
}

variable "headless" {
  type        = bool
  description = "Run the VM without a graphical interface"
  default     = false
}

# --------------------------------------------------
# SSH configuration
# --------------------------------------------------

variable "ssh_username" {
  type        = string
  description = "SSH username used by Packer"
  default     = "vagrant"
}

variable "ssh_password" {
  type        = string
  description = "Temporary SSH password used by Packer. No default: build-box.sh generates one for each build"
  sensitive   = true
}

variable "ssh_password_hash" {
  type        = string
  description = "SHA-512 crypt hash of ssh_password, inserted into the preseed file"
  sensitive   = true
}
