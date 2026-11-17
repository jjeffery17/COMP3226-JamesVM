# Windows 10 test VM (QEMU/KVM)

## 1. Install requirements (Arch)
```
sudo pacman -S qemu-desktop edk2-ovmf socat
```
Your CPU must have virtualization (VT-x/AMD-V) enabled in BIOS, and your user
needs access to `/dev/kvm` (if it doesn't, run `sudo usermod -aG kvm $USER` and log back in).

On other distros, install the equivalent packages and fix the `OVMF_*` paths in `win10.sh`.

## 2. Download the ISO
Get the **64-bit** Windows 10 ISO from
https://www.microsoft.com/software-download/windows10ISO
and save it in this folder as `Win10.iso`.

## 3. Create and install the VM
Set `DIR` and `GUEST_DIR` at the top of `win10.sh` to your paths, then:
```
qemu-img create -f qcow2 win10.qcow2 60G
NET=0 ./win10.sh install
```
Install Windows (Custom install → the empty drive; "I don't have internet" →
local account), then shut down.

## 4. Run
```
./win10.sh run
```
