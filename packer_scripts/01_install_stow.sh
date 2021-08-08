#!/usr/bin/env bash
set -eux -o pipefail

### Load the standard build environment
source /opt/standard_environment/entrypoint.sh bootstrap_mode

### Set the package version and name
package_version="2.3.1"
package_name="stow_${package_version}"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build variable names
src_dir=${STOW_BUILD_CTX_SRC_DIR}
command_tests=${STOW_BUILD_CTX_COMMAND_TEST_DIR}

### Write package test
cat << COMMAND_TEST > "${command_tests}/${package_name}.yaml"
command:
  stow-version:
    exec: "stow --version"
    exit-status: 0
    stdout:
      - "stow (GNU Stow) version ${package_version}"
    timeout: 10000

COMMAND_TEST

### Check for cached source
standard_environment::check_cached_source ${package_name}
if [[ ${STOW_BUILD_CTX_CACHED_SOURCE_EXISTS} == true ]]; then
  ### Move to source directory
  pushd ${src_dir}
    ### Install stow globally
    sudo make install
  popd

  exit 0
fi

### Clone, checkout, build, and install Stow
git clone https://git.savannah.gnu.org/git/stow.git ${src_dir}
pushd ${src_dir}
  git checkout "v${package_version}"

  autoreconf -iv
  ./configure
  make bin/stow
  make bin/chkstow

  ### Install Stow globally
  sudo make install
popd

standard_environment::cache_source ${package_name}

exit 0

