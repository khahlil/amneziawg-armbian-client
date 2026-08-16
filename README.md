# AmneziaWG Client Installer for Armbian

An automated Bash script to compile, install, and configure **AmneziaWG** (a DPI-resistant WireGuard fork) specifically tailored for **Armbian** systems.

---

## Prerequisites

- **OS**: Armbian (Tested on Armbian Trixie / Debian 13)
- **Privileges**: Root access

---

## Quick Start / Installation

```bash
curl -O https://raw.githubusercontent.com/khahlil/amneziawg-armbian-client/main/amnezia-armbian-install.sh
chmod +x amnezia-armbian-install.sh
./amnezia-armbian-install.sh
```
---

## Features

- **DEB822 Support**: Automatically enables `deb-src` in modern `/etc/apt/sources.list.d/debian.sources`.
- **Automated Kernel Building**: Handles dependencies and compiles the `amneziawg` kernel module via DKMS for Armbian kernels.
- **Permanent IP Forwarding**: Automatically sets `net.ipv4.ip_forward=1` via `/etc/sysctl.d/99-amneziawg.conf`.
- **Interactive Setup**: Prompts you to paste your `awg0.conf` directly during installation.
- **Auto-Systemd Integration**: Saves config to `/etc/amnezia/amneziawg/awg0.conf` and enables `awg-quick@awg0` on boot.

---

## Credits & References

- Official Kernel Module: [amnezia-vpn/amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module#debian)
- Official Tools: [amnezia-vpn/amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools)
- Amnezia Project: [amnezia.org](https://amnezia.org)
