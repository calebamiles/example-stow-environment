#!/usr/bin/env bash
set -eux -o pipefail

### Load the standard build environment
source /opt/standard_environment/entrypoint.sh bootstrap_mode

### Set the package version and name
package_version="1.16.7"
package_name="golang_${package_version}"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build variable names
src_dir=${STOW_BUILD_CTX_SRC_DIR}
install_dir=${STOW_BUILD_CTX_PKG_DIR}
command_tests=${STOW_BUILD_CTX_COMMAND_TEST_DIR}

### Write package test
cat << COMMAND_TEST > "${command_tests}/${package_name}.yaml"
command:
  go-version:
    exec: "go version"
    exit-status: 0
    stdout:
      - "go version go${package_version} linux/amd64"
    timeout: 10000

COMMAND_TEST

### Check for cached build and source
standard_environment::check_cached_source ${package_name}
standard_environment::check_cached_build ${package_name}

if [[ ${STOW_BUILD_CTX_CACHED_BUILD_EXISTS} == true ]]; then
  ### Register Golang
  standard_environment::register_package ${package_name}

  exit 0
elif [[ ${STOW_BUILD_CTX_CACHED_SOURCE_EXISTS} == true ]]; then
  pushd "${src_dir}/bootstrap-golang/src"
    git checkout "release-branch.go1.4"

    CGO_ENABLED=0 ./make.bash
  popd

  ### Set bootstrap Golang compiler location
  export GOROOT_BOOTSTRAP="${src_dir}/bootstrap-golang"

  ### Copy the target golang source into the install location
  cp -a "${src_dir}/target-golang"/* ${install_dir}
  pushd "${install_dir}/src"
    git checkout "go${package_version}"

    ./all.bash
  popd

  ### Register the package in the standard environment
  standard_environment::register_package ${package_name}

  ### Cache build output
  standard_environment::cache_build ${package_name}

  exit 0
fi

### Clone, checkout, and build bootstrap Golang compiler
git clone https://go.googlesource.com/go "${src_dir}/bootstrap-golang"
pushd "${src_dir}/bootstrap-golang/src"
  git checkout "release-branch.go1.4"

  CGO_ENABLED=0 ./make.bash
popd

### Set bootstrap Golang compiler location
export GOROOT_BOOTSTRAP="${src_dir}/bootstrap-golang"

### Clone target Golang compiler
git clone https://go.googlesource.com/go "${src_dir}/target-golang"

### Copy the target golang source into the install location
cp -r "${src_dir}/target-golang"/. ${install_dir}

### Checkout and build target Golang compiler
pushd "${install_dir}/src"
  git checkout "go${package_version}"

  ./all.bash
popd

### Register package in the standard environment
standard_environment::register_package ${package_name}

### Cache build and source outputs
standard_environment::cache_source ${package_name}
standard_environment::cache_build ${package_name}

exit 0

