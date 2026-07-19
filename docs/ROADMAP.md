# Roadmap

## M0 — Boot to Go — complete

Single binary, role dispatch, local Control API, constrained console, minimal
web dashboard, tests, FreeBSD cross-build and a reproducible FreeBSD 15.1
QEMU/KVM development environment.

## M1 — GO9_VM kernel — in validation

- FreeBSD 15.1 `GO9_VM` kernel profile for the controlled development VM;
- explicit VirtIO/UFS, VNET, RACCT/RCTL, Capsicum and PF capability set;
- reduced VM-irrelevant hardware support;
- separate persistent kernel source/build disk;
- alternate `/boot/kernel.go9vm` installation;
- one-shot `nextboot` validation with unchanged `GENERIC` recovery kernel;
- existing `go9` integration tests executed after the custom-kernel boot.

M1 does not reduce the FreeBSD world, replace FreeBSD PID 1 or define the
future physical-server driver matrix.

## Later milestones

Minimal FreeBSD world/image construction, production PID 1 behavior, jails,
App Center, PXE, clustering, 9P, WASM and storage replication remain separate
milestones.
