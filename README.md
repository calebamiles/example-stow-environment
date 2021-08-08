# An example stow managed developer environment

## What

A basic example of using [GNU Stow][] to manage a small collection of mostly source packages released as
a [Vagrant][] [base box][].

[GNU Stow]: https://www.gnu.org/software/stow/
[Vagrant]: https://www.vagrantup.com/
[base box]: https://www.vagrantup.com/docs/boxes/base

## Why

Some possible reasons to an approach like this include: 

- an interest in building dependencies from source for [speed][], [safety][], or out of necessity
- an interest in bundling dependencies into multiple formats such as a "container image"
- an interest in [img][] or [buildah][]
- you like [Packer][] and [Vagrant][]
- you're not quite ready for [Nix][]

[speed]: https://blog.kalvad.com/compile-your-softwares/
[safety]: https://www.npr.org/2021/04/16/985439655/a-worst-nightmare-cyberattack-the-untold-story-of-the-solarwinds-hack
[Nix]: https://nixos.org/
[img]: https://github.com/genuinetools/img
[buildah]: https://github.com/containers/buildah
[Packer]: https://www.packer.io/

## Example packages

Example package implementations ~~are~~ will be included for:

- [go][]
- [cfssl][]
- [buf][]
- [grpcurl][]
- [ghz][]
- [k6][]
- [duckdb][]
- [img][]
- [containerd][]
- [seaweedfs][]
- [timescaledb][]

[go]: https://golang.org/
[cfssl]: https://github.com/cloudflare/cfssl
[buf]: https://buf.build/
[grpcurl]: https://github.com/fullstorydev/grpcurl
[ghz]: https://ghz.sh/
[k6]: https://k6.io/
[duckdb]: https://duckdb.org/
[img]: https://github.com/genuinetools/img
[containerd]: https://containerd.io/
[seaweedfs]: https://github.com/chrislusf/seaweedfs
[timescaledb]: https://www.timescale.com/

## Possibe extensions

### Packaged GNU build chain

- technical computing needs "exotic" compilers 

### Foundation for private package layering with Vagrant
Using [ssh agent forwarding][] makes it easy to access private source repositories
when creating an environment using a base box which could contain open source or
otherwise publically available source code.

[ssh agent forwarding]: https://www.vagrantup.com/docs/vagrantfile/ssh_settings#config-ssh-forward_agent

### Remote build caching

Download cached builds from a remote endpoint is fairly simple with a tool like `curl`:

```
work_dir=$(mktemp -d)
cache_url=${YOUR_CACHE_URL_AVAILABLE_TO_VM}

if [[ $(curl -s -f -I "${cache_url}/${STOW_BUILD_CTX_CACHED_BUILD_ID}") ]]; then
  pushd ${work_dir}
    ### Download cached bits
    echo "cached build ${STOW_BUILD_CTX_CACHED_BUILD_ID} exists. Downloading cached build and source..."
    curl "${cache_url}/${STOW_BUILD_CTX_CACHED_BUILD_ID}" > ${STOW_BUILD_CTX_CACHED_BUILD_ID}
    curl "${cache_url}/${STOW_BUILD_CTX_CACHED_SRC_ID}" > ${STOW_BUILD_CTX_CACHED_SRC_ID}
 popd
```

It's not hard to imagine augmenting that simple `curl` invocation with authorization headers, or replacing
curl with a CLI to access S3 or GCS with some reasonable scheme for authentication.

### GPG checksum validation

Those concerend about [supply chain security][], might try using [GPG][] to verify artifact integrity.

Given: 

```
${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}
${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM}
${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE}
${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM_SIGNATURE}
```

where:
- `${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}` is a file produced by `sha256sum ${STOW_BUILD_CTX_CACHED_BUILD_ID}` or similar
- `${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE}` the result of signing `${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}`
   with `gpg` or similar
- `${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM}` is the source analog of `${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}`
- `${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM_SIGNATURE}` is the source analog of
  `${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE}`

the signature of the signed archive can be transmitted and verified
```
### Verify GPG signatures
echo "Verifying GPG signatures for cached build and source..."
gpg --output ${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM} --decrypt ${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE}
gpg --output ${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM} --decrypt ${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM_SIGNATURE}

### Verify SHA256 checksums
echo "Verifying cached build and source checksums..."
sha256sum -C ${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM}
sha256sum -c ${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM}
```

If `gpg` has been configued to trust the expected signing key of the artifacts it's possible to have a slightly stronger GPG check 

```
set -x

### Verify GPG signatures
echo "Verifying GPG signatures for cached build and source..."
gpg --output ${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM} --decrypt ${STOW_BUILD_CTX_CACHED_BUILD_CHECKSUM_SIGNATURE} |& grep -v "WARNING" 
gpg --output ${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM} --decrypt ${STOW_BUILD_CTX_CACHED_SRC_CHECKSUM_SIGNATURE} |& grep -v "WARNING" 
```

which will produce an error on any warnings from `gpg` such as the signing key of the artifact being of unknown trust.
Reasonable people [disagree] as to the utility of using GPG for this task.

[supply chain security]: https://github.blog/2020-09-02-secure-your-software-supply-chain-and-protect-against-supply-chain-threats-github-blog/
[GPG]: https://gnupg.org/
[disagree]: https://blog.gtank.cc/modern-alternatives-to-pgp/

