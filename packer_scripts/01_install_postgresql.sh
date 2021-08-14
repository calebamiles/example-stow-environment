#!/usr/bin/env bash
set -eux -o pipefail

### Load the standard environment
source /opt/standard_environment/entrypoint.sh bootstrap_mode

### Set the package version and name
package_version="13.4"
package_name="postgresql_${package_version}"

### Create build context
standard_environment::create_build_context ${package_name}

### Set friendly build variable names
src_dir=${STOW_BUILD_CTX_SRC_DIR}
install_dir=${STOW_BUILD_CTX_PKG_DIR}
command_tests=${STOW_BUILD_CTX_COMMAND_TEST_DIR}

### Write package test
cat << COMMAND_TEST > "${command_tests}/${package_name}.yaml"
command:
  psql-version:
    exec: "psql --version"
    exit-status: 0
    stdout:
      - "psql (PostgreSQL) ${package_version}"
    timeout: 10000
  postgres-version:
    exec: "postgres --version"
    exit-status: 0
    stdout:
      - "postgres (PostgreSQL) ${package_version}"
    timeout: 10000

COMMAND_TEST

### Check for cached build and source
standard_environment::check_cached_source ${package_name}
standard_environment::check_cached_build ${package_name}

if [[ ${STOW_BUILD_CTX_CACHED_BUILD_EXISTS} == true ]]; then
  ### Register CMake
  standard_environment::register_package ${package_name}

  exit 0
elif [[ ${STOW_BUILD_CTX_CACHED_SOURCE_EXISTS} == true ]]; then
  pushd ${src_dir}
    tag="REL_$(echo ${package_version} | awk '{ gsub("\\.", "_"); print $1 }')"
    git checkout "${tag}"

    git checkout ${tag}
    ./configure --prefix=${install_dir} --with-systemd --with-openssl --enable-debug
    make

    make install
  popd

  ### Register the package in the standard environment
  standard_environment::register_package ${package_name}

  ### Cache build output
  standard_environment::cache_build ${package_name}

  exit 0
fi

### Clone, checkout, and build postgres
git clone https://git.postgresql.org/git/postgresql.git ${src_dir}
pushd ${src_dir}
  tag="REL_$(echo ${package_version} | awk '{ gsub("\\.", "_"); print $1 }')"

  git checkout ${tag}
  ./configure --prefix=${install_dir} --with-systemd --with-openssl --enable-debug
  make

  make install
popd

### Register postgres
standard_environment::register_package ${package_name}

exit 0

