#!/usr/bin/env bash
set -eux -o pipefail

### Load the standard environment
source /opt/standard_environment/entrypoint.sh

### Set the "package" name
package_name="standard_environment_tests"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build variable names
install_dir=${STOW_BUILD_CTX_PKG_DIR}
tmp_dir=${STOW_BUILD_CTX_TMP_DIR}
test_root=${STOW_BUILD_CTX_TEST_ROOT}

### Create installation subdirectory
install_target="${install_dir}/etc/contracts.d"
mkdir -p ${install_target}

### Render gossfile and test environment
pushd ${tmp_dir}
  goss -g "${test_root}/goss.yaml" render > goss.yaml
  goss validate

  ### Install rendered gossfile
  mv goss.yaml ${install_target}
popd

### Register "package"
standard_environment::register_package ${package_name}

exit 0

