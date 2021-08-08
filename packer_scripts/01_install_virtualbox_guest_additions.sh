#!/usr/bin/env bash
set -eux -o pipefail

# Determine the type of guest we are
# https://unix.stackexchange.com/questions/89714/easy-way-to-determine-virtualization-technology
product_name=$(sudo dmidecode -s system-product-name)
case ${product_name} in

  VirtualBox)
    # Create a scratch directory
    work_dir=$(mktemp -d)

    # Mount the disk image
    sudo mount -t iso9660 -o loop /home/vagrant/VBoxGuestAdditions.iso ${work_dir}

    # Install Guest Additions
    pushd ${work_dir}
      # VBoxLinuxAdditions.run will return exit code 2 because video acceleration is not enabled for this headless VM
      sudo ./VBoxLinuxAdditions.run || true 
    popd
 
    # Cleanup
    sudo umount ${work_dir}
    rm -r ${work_dir}

    exit 0
    ;;

  *)
    echo "not attempting to install Virtualbox guest additions for a ${product_name} guest"
    exit 0
    ;;

esac

exit 0

