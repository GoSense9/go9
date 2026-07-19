# GO9_VM kernel profile

`GO9_VM` is the first GoSense9 custom FreeBSD kernel profile. It targets only
the controlled FreeBSD 15.1-RELEASE amd64 QEMU/KVM development VM. It is not
the general server kernel and it is not yet the production HardenedBSD kernel.

## Safety model

- `/boot/kernel` remains the known-good FreeBSD `GENERIC` kernel.
- `GO9_VM` installs separately as `/boot/kernel.go9vm`.
- `nextboot` selects `kernel.go9vm` for one boot only.
- A failed custom-kernel boot does not replace `GENERIC`; another normal reboot
  returns to the default kernel.
- Kernel source and object files live on a separate sparse 16 GB VirtIO disk.
- `make freebsd-vm-clean` preserves that build disk.

## Scope

The initial profile derives from the matching FreeBSD `GENERIC` configuration.
It retains the facilities required by GoSense9 and the development VM:

- amd64, SMP, ACPI and serial/recovery console support;
- UFS root and the CAM/CD path needed by the NoCloud seed;
- VirtIO block and network devices;
- IPv4, IPv6 and BPF/DHCP support;
- jails and VNET through `VIMAGE`;
- `RACCT` and `RCTL`, enabled by default;
- Capsicum capability mode and capabilities;
- PF, `pflog`, `pfsync`, bridge and epair compiled into the kernel;
- an OpenZFS module build for later image/storage work.

The profile removes hardware families that the controlled VM cannot use,
including physical RAID/SCSI/NIC families, Wi-Fi, audio, CardBus, parallel
ports, Hyper-V and Xen guest devices.

## First run after pulling M1

The persistent build disk is attached only when QEMU starts. Restart the VM
without deleting its system overlay:

```sh
make freebsd-vm-down
make freebsd-vm-up
```

Then prepare the dedicated disk and FreeBSD source tree:

```sh
make freebsd-kernel-prepare
```

This step:

1. finds only the VirtIO disk with serial `GO9KERNELBUILD`;
2. refuses to touch a disk with an unexpected partition table;
3. creates the GPT/UFS filesystem labelled `go9build` on first use;
4. mounts it at `/mnt/go9-kernel`;
5. installs Git when needed;
6. shallow-clones FreeBSD `releng/15.1`;
7. stages `freebsd/kernel/GO9_VM` into the source tree.

## Build and one-shot boot

Run each stage separately and inspect its result before continuing:

```sh
make freebsd-kernel-build
make freebsd-kernel-install
make freebsd-kernel-status
make freebsd-kernel-boot-test
```

`freebsd-kernel-boot-test` schedules one boot into `kernel.go9vm`, reboots the
guest, waits for SSH to disappear and return, then verifies:

- `kern.ident=GO9_VM` and the expected boot file;
- embedded `VIMAGE`, `RACCT`, `RCTL` and Capsicum options;
- PF, bridge and epair availability;
- resource accounting enabled at boot;
- the existing `go9` rc.d service, Control socket and web integration tests.

The test does not make `GO9_VM` the permanent default kernel.

## Status and cleanup

```sh
make freebsd-kernel-status
```

Ordinary VM cleanup preserves the kernel build disk. To deliberately remove
all source and kernel build objects:

```sh
make freebsd-vm-down
make freebsd-kernel-clean-build-disk
```

The next `freebsd-vm-up` recreates an empty sparse build disk.

## Recovery

When the one-shot boot fails before SSH becomes available:

1. inspect the serial console log with `make freebsd-vm-logs`;
2. restart the guest normally;
3. FreeBSD should use `/boot/kernel` (`GENERIC`) because `nextboot` is one-shot;
4. confirm recovery with `make freebsd-vm-test`.

Do not run `freebsd-vm-clean` merely to recover from a kernel test. That would
remove the disposable system overlay and is unrelated to the alternate kernel.
