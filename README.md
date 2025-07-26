# [Nushell](https://www.nushell.sh/) image

This repository builds plain OCI images from the [Nushell's GitHub releases](https://github.com/nushell/nushell/releases).

## Details

-   The images are built once per week on Sunday from the `unknown-linux-musl` version.
-   Every image is tagged with the corresponding Nushell version, but the latest version also gets the `latest` tag (beware of breaking changes).
-   Each image includes the full contents of the release `.tar.gz` in the `/nu/` directory.
-   The images are built with a Nushell script: [`build.nu`](./build.nu).
-   The images are signed with Sigstore's [cosign](https://github.com/sigstore/cosign) and can be verified with `cosign verify --key cosign.pub ghcr.io/blue-build/nushell-image`.

## How to use

```containerfile
FROM ghcr.io/blue-build/nushell-image:0.98.0 as nushell

FROM fedora:40

COPY --from=nushell /nu/nu /usr/bin/nu

RUN nu --version && nu -c "ls | sort-by size"
```
