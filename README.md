This is a POST - archinstall script for lightweight Arch Linux Gaming setups on Microsoft Surface Pro 8

Pre Requisites:
Microsoft Surface Pro 8 with arch linux installed using efistub and UKI bootloader with secureboot disabled and curl and git installed as additional packages.
Partitioning scheme required single root partition and not a secondary home folder.
archlinux must already be installed from the iso using archinstall


The script installs: 
Linux-Surface Kernel with Secure Boot working (AND YES! touchscreen/keyboard/trackpad/surfacepen work!)
firefox
steam
gamemode
Uncomplicated Firewall enabled, with default deny incoming default allow outgoing rules.
intel firmware and irisxe graphics
sets cpu to performance mode
Gaming optimizations like mesa/vulkan libraries which intel processors and gpu's rely on
The Cosmic Desktop Environment
16 GB Swap File fore Gaming Performance and Stability
