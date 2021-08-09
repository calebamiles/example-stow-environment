#!/usr/bin/env bash
set -eux -o pipefail

### Ensure some global variables are set
### allow caller to override the standard environment location
standard_environment=${STOW_ENVIRONMENT_LOCATION:-"/opt/standard_environment"}
store_dir="${standard_environment}/store"
cache_dir="${standard_environment}/cache"
source_dir="${standard_environment}/src"
entrypoint="${standard_environment}/entrypoint.sh"
package_list="${standard_environment}/packages.stow"

test_root="${standard_environment}/contracts.d"
command_tests="${test_root}/commands"
package_tests="${test_root}/packages"
service_tests="${test_root}/services"
file_tests="${test_root}/files"
gossfile="${test_root}/goss.yaml"

### Ensure that the package store exists
sudo mkdir -p ${store_dir}

### Ensure that the cache directory exists
sudo mkdir -p ${cache_dir}

### Ensure that the source directory exists
sudo mkdir -p ${source_dir}

### Ensure that the entrypoint, and package list exist
sudo touch ${entrypoint}
sudo touch ${package_list}

### Ensure that the test directories exist
sudo mkdir -p ${command_tests}
sudo mkdir -p ${package_tests}
sudo mkdir -p ${service_tests}
sudo mkdir -p ${file_tests}

### Drop permissions on the entrypoint, and test structure
if [[ $(whoami) != "root" ]]; then
  sudo chown $(whoami):$(whoami) ${entrypoint} ${package_list}
  sudo chown -R $(whoami):$(whoami) ${test_root}
fi

### Write the test entrypoint
cat << ENVIRONMENT_TEST_ENTRYPOINT > ${gossfile}
gossfile:
  ${command_tests}/*.yaml: {}
  ${package_tests}/*.yaml: {}
  ${service_tests}/*.yaml: {}
  ${file_tests}/*.yaml: {}

ENVIRONMENT_TEST_ENTRYPOINT

### Write empty test stubs
cat << EMPTY_COMMAND_TEST > "${command_tests}/empty_test.yaml"
command: {}

EMPTY_COMMAND_TEST

cat << EMPTY_PACKAGE_TEST > "${package_tests}/empty_test.yaml"
package: {}

EMPTY_PACKAGE_TEST

cat << EMPTY_SERVICE_TEST > "${service_tests}/empty_test.yaml"
service: {}

EMPTY_SERVICE_TEST

cat << EMPTY_FILE_TEST > "${file_tests}/empty_test.yaml"
file: {}

EMPTY_FILE_TEST

### Write the environment entrypoint
cat << 'STOW_ENV_ENTRYPOINT' > ${entrypoint}
#!/usr/bin/env bash
set -eux -o pipefail

### Export build variables to environment
###
standard_environment::export_build_variables() {
  local package_name=${1}
  local package_build_script=${0}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Export build variables
  export STOW_BUILD_CTX_RUN_DIR="/usr/local"
  export STOW_BUILD_CTX_CACHE_DIR="/opt/standard_environment/cache"
  export STOW_BUILD_CTX_SRC_ROOT="/opt/standard_environment/src"
  export STOW_BUILD_CTX_PKG_ROOT="/opt/standard_environment/store"
  export STOW_BUILD_CTX_SRC_DIR="${STOW_BUILD_CTX_SRC_ROOT}/${package_name}"
  export STOW_BUILD_CTX_PKG_DIR="${STOW_BUILD_CTX_PKG_ROOT}/${package_name}"

  ### Export test variables
  export STOW_BUILD_CTX_TEST_ROOT="/opt/standard_environment/contracts.d"
  export STOW_BUILD_CTX_COMMAND_TEST_DIR="${STOW_BUILD_CTX_TEST_ROOT}/commands"
  export STOW_BUILD_CTX_PACKAGE_TEST_DIR="${STOW_BUILD_CTX_TEST_ROOT}/packages"
  export STOW_BUILD_CTX_SERVICE_TEST_DIR="${STOW_BUILD_CTX_TEST_ROOT}/services"
  export STOW_BUILD_CTX_FILE_TEST_DIR="${STOW_BUILD_CTX_TEST_ROOT}/files"

  ### Export computed package and stow platform fingerprints
  export STOW_BUILD_CTX_PLATFORM_FINGERPRINT=$(cat <(uname -r) <(ldd --version) | sha256sum | awk '{print $1}')
  export STOW_BUILD_CTX_PACKAGE_FINGERPRINT=$(sha256sum ${package_build_script} | awk '{print $1}')

  ### Export computed cached build variables
  export STOW_BUILD_CTX_CACHED_BUILD_ID="${package_name}-${STOW_BUILD_CTX_PACKAGE_FINGERPRINT}-${STOW_BUILD_CTX_PLATFORM_FINGERPRINT}-out.xz"
  export STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM="${STOW_BUILD_CTX_CACHED_BUILD_ID}.checksum"
  export STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE="${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}.sig"
  
  ### Export computed cached source build variables
  export STOW_BUILD_CTX_CACHED_SRC_ID="${package_name}-${STOW_BUILD_CTX_PACKAGE_FINGERPRINT}-${STOW_BUILD_CTX_PLATFORM_FINGERPRINT}-src.xz"
  export STOW_BUILD_CTX_CACHED_SRC_CHECKSUM="${STOW_BUILD_CTX_CACHED_SRC_ID}.checksum"
  export STOW_BUILD_CTX_CACHED_SRC_CHECKSUM_SIGNATURE="${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM}.sig"
}

### Create build context which includes:
### - directory for source inputs
### - directory for build artifacts
###
standard_environment::create_build_context() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Ensure build environment variables are set
  standard_environment::export_build_variables ${package_name}

  ### Create directories to hold the source and final package
  sudo mkdir -p ${STOW_BUILD_CTX_PKG_DIR}
  sudo mkdir -p ${STOW_BUILD_CTX_SRC_DIR}

  ### Drop permissions on source and package directories
  if [[ $(whoami) != "root" ]]; then
    sudo chown -R $(whoami):$(whoami) ${STOW_BUILD_CTX_PKG_DIR}
    sudo chown -R $(whoami):$(whoami) ${STOW_BUILD_CTX_SRC_DIR}
  fi

  ### Create a temporary scratch space for package installers
  export STOW_BUILD_CTX_TMP_DIR=$(mktemp -d)
  trap "{ rm -r ${STOW_BUILD_CTX_TMP_DIR}; }" EXIT
}

standard_environment::check_cached_source() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Ensure build environment variables are set
  standard_environment::export_build_variables ${package_name}

  ### Create a work directory to hold cached artifacts
  ### attempt to clean up the work directory on exit
  local work_dir=$(mktemp -d)
  trap "{ rm -r ${work_dir}; }" EXIT

  ### Assume no cached source exists
  export STOW_BUILD_CTX_CACHED_SOURCE_EXISTS=false

  if [[ -f "/tmp/${STOW_BUILD_CTX_CACHED_SRC_ID}" ]]; then
    ### Unpack source artifacts
    sudo tar -C ${STOW_BUILD_CTX_SRC_ROOT} -xvf "/tmp/${STOW_BUILD_CTX_CACHED_SRC_ID}"

    ### Drop permissions source directory
    if [[ $(whoami) != "root" ]]; then
        sudo chown -R $(whoami):$(whoami) ${STOW_BUILD_CTX_SRC_DIR}
    fi

    ### Move cached source artifact to cache
    sudo mv "/tmp/${STOW_BUILD_CTX_CACHED_SRC_ID}" ${STOW_BUILD_CTX_CACHE_DIR}

    ### Update the environment to report that cached source exists
    export STOW_BUILD_CTX_CACHED_SOURCE_EXISTS=true
  fi
}

### Check for a cached build
standard_environment::check_cached_build() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Ensure build environment variables are set
  standard_environment::export_build_variables ${package_name}

  ### Assume no cached build exists
  export STOW_BUILD_CTX_CACHED_BUILD_EXISTS=false

  if [[ -f "/tmp/${STOW_BUILD_CTX_CACHED_BUILD_ID}" ]]; then
    ### Unpack cached build artifacts
    sudo tar -C ${STOW_BUILD_CTX_PKG_ROOT} -xvf "/tmp/${STOW_BUILD_CTX_CACHED_BUILD_ID}"

    ### Drop permissions on package directory 
    if [[ $(whoami) != "root" ]]; then
        sudo chown -R $(whoami):$(whoami) ${STOW_BUILD_CTX_PKG_DIR}
    fi

    ### Move cached build artifact to cache
    sudo mv "/tmp/${STOW_BUILD_CTX_CACHED_BUILD_ID}" ${STOW_BUILD_CTX_CACHE_DIR}

    ### Update the environment to report that a cached build exists
    export STOW_BUILD_CTX_CACHED_BUILD_EXISTS=true
  fi
}

standard_environment::cache_source() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Ensure build environment variables are set
  standard_environment::export_build_variables ${package_name}

  ### Archive source artifacts
  echo "Archiving source artifacts..."
  tar -C ${STOW_BUILD_CTX_SRC_ROOT} -cvf ${STOW_BUILD_CTX_CACHED_SRC_ID} ${package_name}

  ### Move source artifacts to local cache
  echo "Moving source archive to local cache..."
  sudo mv ${STOW_BUILD_CTX_CACHED_SRC_ID} ${STOW_BUILD_CTX_CACHE_DIR}
}

standard_environment::cache_build() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Ensure build environment variables are set
  standard_environment::export_build_variables ${package_name}

  ### Archive build artifacts
  echo "Archiving build artifacts..."
  tar -C ${STOW_BUILD_CTX_PKG_ROOT} -cvf ${STOW_BUILD_CTX_CACHED_BUILD_ID} ${package_name}

  ### Move build artifacts to local cache
  echo "Moving build archive to local cache..."
  sudo mv ${STOW_BUILD_CTX_CACHED_BUILD_ID} ${STOW_BUILD_CTX_CACHE_DIR}
}

standard_environment::register_package() {
  local package_name=${1}

  ### Ensure that package_name is populated
  if [[ -z ${package_name} ]]; then
    echo "package_name is a required argument"
    exit 1
  fi

  ### Add package to the package list
  echo "STANDARD_STOW_PACKAGES+=(${package_name})" >> /opt/standard_environment/packages.stow 

  ### Clean up the package list
  sudo cp /opt/standard_environment/packages.stow{,.unsorted} 
  cat /opt/standard_environment/packages.stow.unsorted | sort | uniq > /opt/standard_environment/packages.stow
  sudo rm /opt/standard_environment/packages.stow.unsorted
}

### Export standard environment functions
export -f standard_environment::create_build_context
export -f standard_environment::check_cached_source
export -f standard_environment::check_cached_build
export -f standard_environment::cache_source
export -f standard_environment::cache_build
export -f standard_environment::register_package

### Perform entrypoint directive
### Default: load the packages into 
###  the environment and runs tests
###
### Notes:
### - goss MUST be available on PATH
###   if tests are run; the `bootstrap-mode`
###   directive can be used to perform
###   basic build tasks before goss 
###   is available but NO TESTS WILL BE
###   RUN AUTOMATICALLY in this mode
### - individual packages may be loaded into,
###   or dropped from the environment with the
###   {`with_packages`,`drop_packages`}
###   directives. In these modes NO TESTS
###   WILL BE RUN AUTOMATICALLY.
op=${1:-install_packages}
case ${op} in
  bootstrap_mode)
    ### nothing more to do in bootstrap mode
    ;;

  install_packages)
    ### Create array to hold the list packages
    declare -a STANDARD_STOW_PACKAGES

    ### Load the list of packages
    source /opt/standard_environment/packages.stow

    ### Restow the packages
    for pkg in "${STANDARD_STOW_PACKAGES[@]}"; do
      sudo stow --dir /opt/standard_environment/store --target /usr/local --restow ${pkg}
    done

    ### Check stow
    sudo chkstow --target /usr/local --badlinks

    ### Create scratch directory for rendered gossfile
    test_dir=$(mktemp -d)
    trap "{ rm -r ${test_dir}; }" EXIT

    ### Render gossfile and run tests
    goss -g /opt/standard_environment/contracts.d/goss.yaml render > "${test_dir}/goss.yaml"
    goss -g "${test_dir}/goss.yaml" validate -f silent
    ;;

  uninstall_packages)
    ### Create array to hold the list packages
    declare -a STANDARD_STOW_PACKAGES

    ### Load the list of packages
    source /opt/standard_environment/packages.stow
 
    ### Remove package symlinks
    for pkg in "${STANDARD_STOW_PACKAGES[@]}"; do
      sudo stow --dir /opt/standard_environment/store --target /usr/local --delete ${pkg}
    done

    ### Check stow
    sudo chkstow --target /usr/local --badlinks
    ;;

  with_packages)
    ### Save the list of packages to load
    pkgs=${2}

    ### Check that required programs exist
    if [[ ! $(command -v sudo) ]]; then
      echo "sudo was not found on PATH...exiting"
      exit 1
    fi

    if [[ ! $(command -v stow) ]]; then
      echo "stow was not found on PATH...exiting"
      exit 1
    fi
 
    ### Load specified packages
    for pkg in "${pkgs[@]}"; do
      sudo stow --dir /opt/standard_environment/store --target /usr/local --restow ${pkg}
    done

    ### Try and drop packages on exit
    trap "{ /opt/standard_environment/entrypoint.sh drop_packages ${pkgs}; }" EXIT
    ;;

  drop_packages)
    ### Save the list of packages to drop
    pkgs=${2}

    ### Drop specified packages
    for pkg in "${pkgs[@]}"; do
      sudo stow --dir /opt/standard_environment/store --target /usr/local --delete ${pkg}
    done
    ;;

  *)
    echo "invalid entrypoint action"
    exit 1
    ;;

esac

### Unset variables
unset STANDARD_ENVIRONMENT_STOW_PACKAGES

### Update shared libraries and PATH symbols
sudo ldconfig /usr/local/lib
hash -r

STOW_ENV_ENTRYPOINT

### Make the entrypoint executable
chmod +x ${entrypoint}

### Exit cleanly
exit 0

