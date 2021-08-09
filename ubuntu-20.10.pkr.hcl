source "virtualbox-iso" "stow-developer-env" {
  output_directory = local.virtualbox_output_directory
  guest_os_type    = local.virtualbox_guest_os_type
  http_directory   = local.http_directory

  memory           = local.vm_memory
  disk_size        = local.one_hundred_gb_in_mb

  iso_url          = local.iso_url
  iso_checksum     = local.iso_checksum

  ssh_username     = local.ssh_username
  ssh_password     = local.ssh_password
  ssh_timeout      = local.ssh_timeout

  boot_command     = local.boot_command
  shutdown_command = local.shutdown_command
}

build {
  sources = ["source.virtualbox-iso.stow-developer-env"]

  provisioner "file" {
    source      = "stow_build_cache/"
    destination = "/tmp"
    direction   = "upload"
  }

  provisioner "shell" {
    environment_vars = [
      "FORCE_PROVISIONING=false",
    ]

    scripts = [
      "packer_scripts/00_bootstrap_standard_environment.sh",
      "packer_scripts/00_rehome_cached_artifacts.sh",
      "packer_scripts/01_reserve_disk_space.sh",
      "packer_scripts/01_install_stow.sh",
      "packer_scripts/01_install_cmake.sh",
      "packer_scripts/01_install_virtualbox_guest_additions.sh",
      "packer_scripts/01_install_golang.sh",
      "packer_scripts/02_install_goss.sh",
      "packer_scripts/03_check_standard_environment.sh",
    ]
  }

  provisioner "file" {
    source      = "/opt/standard_environment/cache/"
    destination = "stow_build_cache"
    direction   = "download"
  }

  provisioner "shell-local" {
    scripts = [
      "hack/rehome_cached_artifacts.sh",
    ]
  }
}

locals {
  one_hundred_gb_in_mb = 107374
  vm_memory            = 8192

  http_directory       = "http"

  ssh_username         = "vagrant"
  ssh_password         = "vagrant"
  ssh_timeout          = "30m"

  boot_wait            = "5s"

  boot_command =  [
    " <wait>",
    " <wait>",
    " <wait>",
    " <wait>",
    " <wait>",
    "c",
    "<wait>",
    "set gfxpayload=keep",
    "<enter><wait>",
    "linux /casper/vmlinuz quiet<wait>",
    " autoinstall<wait>",
    " ds=nocloud-net<wait>",
    "\\;s=http://<wait>",
    "{{.HTTPIP}}<wait>",
    ":{{.HTTPPort}}/<wait>",
    " ---",
    "<enter><wait>",
    "initrd /casper/initrd<wait>",
    "<enter><wait>",
    "boot<enter><wait>"
   ]

  shutdown_command  = "sudo -S shutdown -P now"

  iso_url           = "https://releases.ubuntu.com/20.10/ubuntu-20.10-live-server-amd64.iso"
  iso_checksum      = "sha256:defdc1ad3af7b661fe2b4ee861fb6fdb5f52039389ef56da6efc05e6adfe3d45"

  virtualbox_output_directory   = "output_virtualbox_stow_developer_env_ubuntu"
  virtualbox_guest_os_type      = "Ubuntu_64"
}

