# GoSense9 FreeBSD development VM

This directory contains a CachyOS/Arch Linux host workflow for running GoSense9 M0 on a standard FreeBSD guest. It uses FreeBSD 15.1-RELEASE amd64 BASIC-CLOUDINIT UFS qcow2 images, keeps the downloaded base image immutable, and runs `go9` through an rc.d service. It does not replace FreeBSD PID 1.

## Quick start

```sh
make freebsd-dev
```

On success:

```text
GoSense9 dashboard: http://127.0.0.1:8080
FreeBSD SSH: make freebsd-vm-shell
```

## Targets

- `make freebsd-vm-up`: prerequisites, download, seed, overlay, boot, and SSH wait.
- `make freebsd-vm-provision`: cross-compile `go9`, install `/usr/local/sbin/go9`, install rc.d service, enable and restart service.
- `make freebsd-vm-test`: verify FreeBSD version, service, socket permissions, web pages, `freebsd/amd64` status, and local-only web assets.
- `make freebsd-vm-shell`: open SSH to the guest.
- `make freebsd-vm-logs`: follow QEMU serial logs.
- `make freebsd-vm-down`: stop QEMU.
- `make freebsd-vm-clean`: remove generated overlay/seed/test artifacts while preserving the base image.

Required host tools include QEMU, `qemu-img`, OpenSSH, `curl`, `sha256sum`, Go, and one NoCloud ISO generator (`cloud-localds`, `genisoimage`, or `mkisofs`).
