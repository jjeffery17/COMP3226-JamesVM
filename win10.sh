#!/usr/bin/env bash
# Baseline Windows 10 QEMU/KVM guest for VM-detection testing.
# Deliberately "stock": no hiding of hypervisor signals, so detection tools
# should fire. Hardening (signal modifiers) gets layered on later.
#
# Usage:
#   ./win10.sh install            boot from Win10.iso (first-time install)
#   ./win10.sh run                normal boot from disk
#   ./win10.sh snap <name>        create internal qcow2 snapshot (VM must be off)
#   ./win10.sh revert <name>      revert disk to snapshot (VM must be off)
#   ./win10.sh snaps              list snapshots
#
# Env overrides: RAM (MiB, default 4096), CPUS (default 2), NET=0 to disable
# networking (handy for forcing a local account during setup), DISPLAY_BACKEND,
# TRANSFER=1 to attach guest/ for copying the test system in (see below).

set -euo pipefail
DIR="/home/james/Documents/University/COMP3226/vms/qemu-vm"

DISK="$DIR/win10.qcow2"
WIN_ISO="$DIR/Win10.iso"
VIRTIO_ISO="/var/lib/libvirt/images/virtio-win.iso"
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
OVMF_VARS="$DIR/win10_VARS.fd"     # per-VM writable UEFI NVRAM
GUEST_DIR="/home/james/Documents/University/COMP3226/guest"   # test system source (TRANSFER=1)

RAM="${RAM:-4096}"
CPUS="${CPUS:-2}"
NET="${NET:-1}"
TRANSFER="${TRANSFER:-0}"
DISPLAY_BACKEND="${DISPLAY_BACKEND:-gtk}"

mode="${1:-run}"

case "$mode" in
  snap)   qemu-img snapshot -c "${2:?snapshot name}" "$DISK"; exit ;;
  revert) qemu-img snapshot -a "${2:?snapshot name}" "$DISK"; exit ;;
  snaps)  qemu-img snapshot -l "$DISK"; exit ;;
  install|run) ;;
  *) echo "unknown mode: $mode" >&2; exit 1 ;;
esac

[[ -f "$OVMF_VARS" ]] || cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

args=(
  -name win10-baseline
  -machine q35,accel=kvm
  -cpu host
  -smp "$CPUS"
  -m "$RAM"
  -rtc base=localtime

  # UEFI firmware (no Secure Boot / TPM needed for Win10)
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
  -drive if=pflash,format=raw,file="$OVMF_VARS"

  # System disk on emulated AHCI/SATA: Windows has inbox drivers, no F6 step
  -device ahci,id=ahci
  -drive id=disk0,if=none,format=qcow2,file="$DISK"
  -device ide-hd,drive=disk0,bus=ahci.0,bootindex=1

  # Display / input
  -vga std
  -display "$DISPLAY_BACKEND"
  -device qemu-xhci
  -device usb-tablet

  # Host<->QEMU control (e.g. `socat - UNIX-CONNECT:$DIR/qmp.sock`)
  -qmp unix:"$DIR/qmp.sock",server=on,wait=off
)

if [[ "$NET" == 1 ]]; then
  args+=(-nic user,model=e1000e)
else
  args+=(-nic none)
fi

if [[ "$mode" == install ]]; then
  args+=(
    -drive id=cd0,if=none,media=cdrom,readonly=on,file="$WIN_ISO"
    -device ide-cd,drive=cd0,bus=ahci.1,bootindex=0
  )
  # The Win10 DVD's UEFI loader shows "Press any key to boot from CD or DVD"
  # for ~5s and falls through to the firmware boot menu if missed. Tap space
  # over QMP for the first 20s so it always catches the prompt.
  (
    for _ in $(seq 40); do
      [[ -S "$DIR/qmp.sock" ]] && printf '%s\n' \
        '{"execute":"qmp_capabilities"}' \
        '{"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":"spc"}]}}' \
        | socat -t0.2 - UNIX-CONNECT:"$DIR/qmp.sock" >/dev/null 2>&1 || true
      sleep 0.5
    done
  ) &
fi

# Transfer drive (TRANSFER=1 only): host guest/ folder appears in Windows as a
# small FAT disk; run install.cmd on it to copy the test system to
# Desktop\vmtests. Not attached by default, so normal runs have no shared
# folder. snapshot=on: guest writes are discarded, the host folder is never
# touched. Keep guest/ under ~500 MB (FAT16 limit).
if [[ "$TRANSFER" == 1 ]]; then
  args+=(
    -drive id=share,if=none,snapshot=on,file=fat:16:"$GUEST_DIR",format=vvfat
    -device ide-hd,drive=share,bus=ahci.3
  )
fi

# virtio-win ISO always attached so drivers/guest tools are available if wanted
if [[ -f "$VIRTIO_ISO" ]]; then
  args+=(
    -drive id=cd1,if=none,media=cdrom,readonly=on,file="$VIRTIO_ISO"
    -device ide-cd,drive=cd1,bus=ahci.2
  )
fi

exec qemu-system-x86_64 "${args[@]}"
