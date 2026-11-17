# Requirements for win10.sh

## Hardware
- x86-64 CPU with virtualization (Intel VT-x / AMD-V) enabled in BIOS/UEFI
- ~4 GB free RAM for the guest, ~60 GB disk for `win10.qcow2`

## Packages (Arch)
```
sudo pacman -S qemu-desktop edk2-ovmf socat
```
- `qemu-desktop`: qemu-system-x86_64, qemu-img, GTK display
- `edk2-ovmf`: UEFI firmware
- `socat`: used by `install` mode to auto-press the boot-from-DVD key
- optional: `virtio-win` (AUR). The script skips it if it's missing.

Other distros: Debian/Ubuntu `qemu-system-x86 qemu-utils ovmf socat`,
Fedora `qemu-kvm qemu-img edk2-ovmf socat`. Their firmware paths differ, so
update `OVMF_CODE` / `OVMF_VARS_TEMPLATE` in win10.sh to match.

## KVM access
- `ls -l /dev/kvm` must be readable/writable by your user; if not:
  `sudo usermod -aG kvm $USER`, then log out and back in

## Files
- `Win10.iso`: **64-bit** (x64) Windows 10 ISO, next to win10.sh
- `win10.qcow2`: `qemu-img create -f qcow2 win10.qcow2 60G`
- the paths `DIR` and `GUEST_DIR` at the top of win10.sh point at this machine, so update them
