#!/usr/bin/env bash
set -eux -o pipefail

### Load standard environment
source /opt/standard_environment/entrypoint.sh bootstrap_mode

### Set package name
package_name="disk_reservation"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build names
test_dir=${STOW_BUILD_CTX_FILE_TEST_DIR}
install_dir=${STOW_BUILD_CTX_PKG_DIR}

### Write test
cat << FILE_TEST > "${test_dir}/disk-reservation"
file:
  "${install_dir}/disk_reservation":
    exists: true
FILE_TEST

fallocate -l 40G "${install_dir}/disk_reservation"

exit 0

