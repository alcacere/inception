# inception.pkr.hcl - Packer template for unattended Debian VM installation

packer {
  required_version = ">= 1.7.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.1.5"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "virtualbox-iso" "debian" {
  vm_name              = var.vm_name
  guest_os_type        = "Debian_64"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  headless             = var.headless
  guest_additions_mode = "disable"

  # Served from memory, so the rendered preseed (with the hash) is never written to disk.
  http_content = {
    "/preseed.cfg" = templatefile("${abspath(path.root)}/http/preseed.cfg", {
      password_hash = var.ssh_password_hash
    })
  }
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "install ",
    "auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "<enter>"
  ]

  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  shutdown_command = "sudo shutdown -P now"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--nat-localhostreachable1", "on"],
    ["modifyvm", "{{ .Name }}", "--rtcuseutc", "on"]
  ]
}

build {
  sources = ["source.virtualbox-iso.debian"]

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -E sh -eux '{{ .Path }}'"
    environment_vars = [
      "LOGIN=${var.login}"
    ]
    scripts = [
      "${path.root}/scripts/provision.sh",
      "${path.root}/scripts/cleanup.sh"
    ]
  }

  post-processor "vagrant" {
    output = "${path.root}/output/${var.vm_name}-debian.box"
  }
}
