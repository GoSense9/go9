# GoSense9

GoSense9 is a Go-first operating system control plane for HardenedBSD/FreeBSD. The repository and internal technical name are `go9`; the executable is `go9`.

M0 — Boot to Go establishes a single binary with multiple process roles:

- `/sbin/go9 --role=init` development supervisor;
- `go9 --role=control` local Control API on `/run/go9/control.sock`;
- `go9 --role=console` interactive `go9>` console;
- `go9 --role=web` server-rendered HTMX web UI.

## Development

```sh
make build
make test
make vet
make build-freebsd
```

The control socket can be overridden with `--control-socket` or `GO9_CONTROL_SOCKET`. The web listener defaults to `127.0.0.1:8080`.

## FreeBSD development VM

On a CachyOS/Arch Linux host with QEMU/KVM prerequisites installed, run:

```sh
make freebsd-dev
```

This downloads and verifies the official FreeBSD 15.1-RELEASE amd64 BASIC-CLOUDINIT UFS qcow2 image, boots an immutable-base/overlay VM, installs `go9` as `/usr/local/sbin/go9`, enables the rc.d service, and runs integration checks.
