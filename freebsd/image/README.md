# FreeBSD image handling

The development VM scripts download the official FreeBSD 15.1-RELEASE amd64 BASIC-CLOUDINIT UFS qcow2 image and its `CHECKSUM.SHA256` file from `download.freebsd.org` into `.freebsd-vm/`.

The base qcow2 is marked read-only and treated as immutable. Runtime changes are written to a generated qcow2 overlay that can be removed with `make freebsd-vm-clean`.
