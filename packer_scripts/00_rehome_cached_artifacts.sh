#!/usr/bin/env bash
set -eux -o pipefail

### Check if the cache is populated
if [[ -d "/tmp/stow_build_cache" ]]; then
    ### Check if there are cached artifacts
    readarray -d '' artifacts < <(find "/tmp/stow_build_cache/" -name "*.xz" -print0)

    ### Move any cached artifacts up to stow_build_cache 
    for artifact in "${artifacts[@]}"; do
      mv ${artifact} "/tmp"
    done
fi

exit 0

