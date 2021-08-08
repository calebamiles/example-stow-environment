#!/usr/bin/env bash
set -eux -o pipefail

### Check for download stow_build_cache/tmp directory
if [[ -d "stow_build_cache/cache" ]]; then

  ### Check if there are cached artifacts
  readarray -d '' artifacts < <(find "stow_build_cache/cache" -name '*.xz' -print0)
 
  ### Move any cached artifacts up to stow_build_cache 
  for artifact in "${artifacts[@]}"; do
    mv ${artifact} "stow_build_cache"
  done

  ### Remove uploaded stow_build_cache_directory
  rm -r "stow_build_cache/cache"
fi

exit 0

