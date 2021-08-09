#!/usr/bin/env bash
set -eux -o pipefail

### List package dependencies
deps=("golang_1.16.7")

### Load the standard build environment
source /opt/standard_environment/entrypoint.sh with_packages ${deps}

### Set package version and name
package_version="0.3.16"
package_name="goss_${package_version}"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build variable names
src_dir=${STOW_BUILD_CTX_SRC_DIR}
install_dir=${STOW_BUILD_CTX_PKG_DIR}
command_tests=${STOW_BUILD_CTX_COMMAND_TEST_DIR}

### Write package test
cat << COMMAND_TEST > "${command_tests}/${package_name}.yaml"
command:
  goss-version:
    exec: "goss --version"
    exit-status: 0
    stdout:
      - "goss version ${package_version}"
    timeout: 10000

COMMAND_TEST

### Check for cached build and source
standard_environment::check_cached_source ${package_name}
standard_environment::check_cached_build ${package_name}

if [[ ${STOW_BUILD_CTX_CACHED_BUILD_EXISTS} == true ]]; then
  ### Register goss
  standard_environment::register_package ${package_name}

  exit 0
elif [[ ${STOW_BUILD_CTX_CACHED_SOURCE_EXISTS} == true ]]; then
  ### Make installation subdirectory
  mkdir -p "${install_dir}/bin"

  ### Checkout and build goss binaries
  pushd ${src_dir}
    git checkout "v${package_version}"

    TRAVIS_TAG=${package_version} make release/goss-linux-amd64
    mv release/goss-linux-amd64 "${install_dir}/bin/goss"
  popd

  ### Register goss
  standard_environment::register_package ${package_name}

  ### Cache build output and source
  standard_environment::cache_build ${package_name}

  exit 0
fi

### Make installation subdirectory
mkdir -p "${install_dir}/bin"

### Clone, checkout and build goss binaries
git clone https://github.com/aelsabbahy/goss ${src_dir}
pushd ${src_dir}
  git checkout "v${package_version}"

  TRAVIS_TAG=${package_version} make release/goss-linux-amd64
  mv release/goss-linux-amd64 "${install_dir}/bin/goss"
popd

### Register goss
standard_environment::register_package ${package_name}

### Cache build output and source
standard_environment::cache_build ${package_name}
standard_environment::cache_source ${package_name}

exit 0

