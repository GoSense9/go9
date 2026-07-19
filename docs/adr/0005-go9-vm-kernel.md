# ADR 0005: GO9_VM custom FreeBSD kernel

## Status

Proposed for M1 validation.

## Context

M0 runs `go9` as an rc.d service inside a standard FreeBSD 15.1-RELEASE amd64
QEMU/KVM guest. GoSense9 ultimately needs a smaller, auditable kernel with an
explicit capability set, but removing large groups of kernel components before
we have a recovery and test workflow would create unnecessary boot risk.

Kernel source and build objects also do not belong on the small disposable UFS
system overlay used by the development VM.

## Decision

Create an initial kernel configuration named `GO9_VM` with these constraints:

1. derive from the matching upstream `GENERIC` configuration;
2. remove only hardware families absent from the controlled QEMU/KVM VM;
3. retain VirtIO, UFS, recovery console and seed-media support;
4. compile VNET, resource control, Capsicum, PF, bridge and epair capabilities;
5. build only an explicit small module set needed for M1 storage work;
6. install as `/boot/kernel.go9vm`, never over `/boot/kernel`;
7. select it through one-shot `nextboot` during validation;
8. retain `GENERIC` as the normal recovery kernel;
9. keep source and object files on a separate persistent sparse VirtIO disk;
10. validate the running kernel and the existing M0 GoSense9 integration before
    considering the profile stable.

`GO9_VM` is a development-VM profile. It does not define the future
`GO9_SERVER` hardware support matrix and does not yet reduce the FreeBSD world.

## Consequences

- M1 can measure and test kernel reduction without replacing the known-good
  development kernel.
- A failed one-shot boot can recover through the unchanged `GENERIC` kernel.
- The build disk survives ordinary VM-overlay cleanup, avoiding repeated source
  downloads and full rebuilds.
- The first profile remains larger than the eventual appliance kernel because
  it intentionally inherits `GENERIC` and removes components incrementally.
- Every additional removal must be justified by a successful build, one-shot
  boot and integration test.
