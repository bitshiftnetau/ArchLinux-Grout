# BUILDING ARCH MACHINE: 

TODO:
- add linkage for systemd-networkd files using VLANs
- add rofi/picom/i3blocks config/instructions
- 

## System design

- Firmware mode: UEFI + rEFInd
- Paritions: GPT
- Kernel: Linux-lts + linux-lts-headers
- Initramfs: Systemd 
- Encryption: LUKS on LVM

***We are using rEFInd because from memory sytemd-boot is not compatible with LVM on Luks***

## Systemd services:
- Systemd-networkd
- automount: udiskie
- RAID: mdadm
- RDP server: xrdp
- Printers: CUPS


## AUR helper:
- yay

## Desktop
- Display Manager: Xorg
- Window Manager: i3-gaps
- Desktop Bar: i3bar
- Status Bar: i3-blocks w/ plugins from https://github.com/vivien/i3blocks-contrib
- System Tray: i3-blocks native
- Lock screen: i3lock
- Launcher: rofi
- Compositor: picom
- Login Manager: n/a
- Screens: xrandr + arandr

## Automated on desktop launch
- On cli login: startx -> i3
- On i3 launch: feh, pasystray, flameshot, Remmina

## Themes
### Window:
- adwaita-gtk-theme
- arc-gtk-theme (arc-dark as illustrated)
- deepin-gtk-theme
- gnome-themes-extra
- mate-themes
- materia-gtk-theme

### Icons:
- antudark-icons
- breath-dark-icon-theme
- gtk-theme-material-black (selected systemwide)
- suru-plus-dark-git
- hicolor-icon-theme
- ttf-material-icons-git
- obsidian-icon-theme-git

### Cursor:
- breeze-hacked (as illustrated)
- breeze-obsidian
- breeze-purple
- deepinv20-dark-cursors-git

## Fonts
- xorg-fonts-100dpi
- xorg-fonts-75dpi
- cantarell-fonts 
- nerd-fonts-complete
- ttf-dejavu (selected as system-wide)
- cascaydia-fonts
- cascaydia-code-fonts
- freetype2
- ttf-nerd-fonts-symbols

## Miscellaneous Applications:
- RDP/SPICE/XVNC client: Remmina + freerdp
- Audio: alsa, pulseaudio
- Browsers: Firefox, Brave, ~~Chromium~~ ***currently undocumented memory leak in Chromium***
- discord
- gimp
- inkscape
- gucharmap
- gstreamer + gst-plugins-base
- jack2
- keepassxc
- lxappearance
- minecraft-launcher
- nautilus
- neofetch

## Utilities:
- bindutils
- binutils
- coreutils
- bison
- git
- make
- jshon
- bzip2
- lvm
- cryptsetup
- dhcpcd
- curl
- dialog
- diffutils
- vim
- dosfstools
- e2fsprogs
- efibootmgr
- expac
- fakeroot
- gcc
- python
- go
- gnupg
- grub
- htop
- hfsutils
- fuse
- gtk2 + gtk3
- harfbuzz
- iwd
- openssl
- openssh
- yad
- xdotools
- mdadm
- meson
- ntfs-3g
- zip
- xprop
- xterm
- xorg-server
- udisks
- udiskie2


### Installation options:

1. Manually follow the instructions below
2. ~~Run the script attached~~ ***(hopefully coming soon)***


# Installation

- Download a fresh ISO and follow the basic installation guide found on the Arch website: https://wiki.archlinux.org/title/Installation_guide

- When you boot up the usb, select "UEFI" from the installation menu
- At the section titled "Partition the disks", use the following instructions for GPT & LVM inside LUKS (encrypted LVM). These instructions are a collation of various pages in the Arch Wiki that are very thorough but have been distilled here for convenience:

## GPT & LVM inside LUKS (encrypted LVM)

### Prepare the disk for encryption using dm-crypt wipe on an empty disk or partition

- First, create a temporary encrypted container on the partition (using the form sdXY) or complete device (using the form sdX) to be encrypted:
 ```cryptsetup open --type plain -d /dev/urandom /dev/<block-device> disk_clean```

- You can verify that it exists:
 ```lsblk```

```
NAME          MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda             8:0    0  1.8T  0 disk
└─to_be_wiped 252:0    0  1.8T  0 crypt
```

- Wipe the container with zeros. A use of if=/dev/urandom is not required as the encryption cipher is used for randomness.
``` dd if=/dev/zero of=/dev/mapper/disk_clean bs=1M status=progress ```

To perform a check of the operation, zero the partition before creating the wipe container. After the wipe command `blockdev --getsize64 /dev/mapper/container` can be used to get the exact container size as root. Now `od` can be used to spotcheck whether the wipe overwrote the zeroed sectors, e.g. `od -j containersize - blocksize` to view the wipe completed to the end.

- Finally, close the temporary container:
``` cryptsetup close disk_clean ```

### Parition your disk
```
 $ fdisk /dev/sdX
 g (new GPT partition table)
 n (new)
 p (primary... could be extended or wateva suits)
```

- sector start xxxx (refer to table below)
- sector end xxxx (refer to table below)

- Your partition layout should look like this:

```
 Number       Start(sector)     End(sector)     Size        Code Name 
 1            2048              1130495         550.0 MiB   EF00 EFI System 
 2            1130496           69205982        32.3 GiB    8E00 Linux LVM
```

### Create the LUKS encrypted container at the "system" partition.
`$ cryptsetup luksFormat --type luks2 /dev/sda4 ` 

For more information about the available cryptsetup options see the LUKS encryption options prior to above command.

- Open the partition into a cryptcontainer, give the container a name, and assign it to the crypt mapper (btw, you will need to do this before mounting a partition if you boot a recovery usb):
`$ cryptsetup open /dev/sda4 cryptlvm `

The decrypted container is now available at /dev/mapper/cryptlvm.

### Preparing the logical volumes

- Create a physical volume on top of the opened LUKS container:
`$ pvcreate /dev/mapper/cryptlvm`

- Create the volume group named MyVolGroup (or whatever you want), adding the previously created physical volume to it:
`$ vgcreate VolGroup00 /dev/mapper/cryptlvm`

- Create all your logical volumes on the volume group:
 `$ lvcreate -L 20G VolGroup00 -n lvolroot `
 `$ lvcreate -L 12G VolGroup00 -n lvolvar `
 `$ lvcreate -l 100%FREE VolGroup00 -n lvolhome `

- Format your filesystems on each logical volume:
 `$ mkfs.ext4 /dev/MyVolGroup/root `
 `$ mkfs.ext4 /dev/MyVolGroup/home `
 `$ mkfs.ext4 /dev/MyVolGroup/var `
 `$ mkfs.vfat /dev/sda1 `

Notice how we are accessing the volumes through the volume group and not through the cryptmapper. That is because we are accessing the logical volumes, not the underlying luks crypto-container.

### Mount your filesystem:

 `$ mount /dev/MyVolGroup/lvolroot /mnt `
 `$ mkdir /mnt/home `
 `$ mkdir /mnt/var `
 `$ mkdir /mnt/boot `
 `$ mount /dev/MyVolGroup/lvolhome /mnt/home `
 `$ mount /dev/MyVolGroup/lvolvar /mnt/var `
 `$ mount /dev/sda1 /mnt/boot `

## Snapshots (Optional)

Read more about LVM snapshots here: https://wiki.archlinux.org/index.php/LVM#Snapshots 
And more about creating root snapshots here: https://wiki.archlinux.org/index.php/Create_root_filesystem_snapshots_with_LVM

***NOTE: In order to be able to create snapshots you need to have unallocated space in your volume group. Snapshot like any other volume will take up space in the volume group. So, if you plan to use snapshots for backing up your root partition do not allocate 100% of your volume group for root logical volume.***

### System Configuration

- You create snapshot logical volumes just like normal ones.
`$ lvcreate --size 100M --snapshot --name snap01 /dev/VolGroup00/lvolboot-snap01`

- Reverting the modified 'lv' logical volume to the state when the 'snap01' snapshot was taken can be done with
`$ lvconvert --merge /dev/VolGroup00/lvolboot-snap01`

#-------- Install the base packages ----------

- Continue installing in the Installation Guide at https://wiki.archlinux.org/title/Installation_guide#Installation


### Troubleshooting:
- If the installation is broken by an old signature on an old installation media, then just run 
# pacman-key --refresh-keys

Whilst rooted on the installation media and it should be fine.

NOTES:
- When you generate an fstab file, if you use the UUIDs option, make sure they are the PARTUUIDs of the LVM partitions not the physical UUIDs.
- When installing the base packages, microcode for AMD processors comes from `linux-firmware` and microcode for Intel processors come from `intel-ucode`

### Enabling Intel microcode updates
- Microcode must be loaded by the bootloader. Because of the wide variability in users' early-boot configuration, Intel microcode updates may not be triggered automatically by Arch's default configuration. Many AUR kernels have followed the path of the official Arch kernels in this regard.

These updates must be enabled by adding /boot/intel-ucode.img as the first initrd in the bootloader config file. This is in addition to the normal initrd file. See below for instructions using rEFInd

************ REBOOT ***************

### SWITCHING TO LTS KERNEL

- Install linux-lts kernel:
`$ pacman -R linux`
`$ pacman -S linux-lts`

Configure initramfs

- If /etc/vconsole.conf doesn't exist:
`$ touch /etc/vconsole.conf`

### Minitcpio hooks for lvm2 with dcrypt drives

- Edit mkinitcpio.conf
`$ nano /etc/mkinitcpio.conf`

Remove these from HOOKS: udev, lvm2

- add these to HOOKS:
`$ systemd filsystems keyboard sd-vconsole sd-encrypt sd-lvm2 mdadm_udev`

Generate initramfs using lts kernel and the new hooks:
`$ mkinitcpio -p linux-lts`

### Kernel options with LVM inside crypt
If the root file system resides in a logical volume, the root= kernel parameter must be pointed to the mapped device, e.g /dev/vg-name/lv-name.
Configure /etc/mkinitcpio.conf if additional features are needed. Create a new initial RAM disk with:

`$ mkinitcpio -p linux-lts` (if it doesn’t automatically run after installing the new kernel)

### rEFInd

For the following section 'esp' = /boot partition ('esp' simply stands for EFI System Partition. This is the same on the wiki so just take note of that. A little bit misleading tbh but there it is)

Install refind tools:
`$ pacman -S refind-efi sbsigntools imagemagick parted`

Installation with refind-install script

The rEFInd package includes the refind-install script to simplify the process of setting rEFInd as your default EFI boot entry. The script has several options for handling differing setups and UEFI implementations. See refind-install(8) or read the comments in the install script for explanations of the various installation options.

For many systems it should be sufficient to simply run:
`$ refind-install`

This will attempt to find and mount your ESP, copy rEFInd files to esp/EFI/refind/, and use efibootmgr to make rEFInd the default EFI boot application.

When refind-install is run in chroot (e.g. in live system when installing Arch Linux) /boot/refind_linux.conf is populated with kernel options from the live system not the one on which it is installed. You will need to edit /boot/refind_linux.conf and adjust the kernel options manually. See #refind_linux.conf for an example.

### refind_linux.conf and kernel parameters

If rEFInd automatically detects your kernel, you can place a refind_linux.conf file containing the kernel parameters in the same directory as your kernel. You can use /usr/share/refind/refind_linux.conf-sample as a starting point. We're gonna butcher this file because it doesn't suit our needs at all. 

`$ nano /boot/refind_linux.conf`

```
"Runlevel 5: Linux-lts" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts.img rw"

"Runlevel 5: Linux-lts-fallback" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts-fallback.img rw"

"Runlevel 3: Drop to terminal" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts-fallback.img ro systemd.unit=rescue.target"
```

Then we need to send through some extra kernel options in /boot/EFI/refind/refind.conf, uncomment the following lines:

` extra_kernel_version_strings linux,linux-hardened,linux-lts,linux-zen,linux-git;`
` fold_linux_kernels false`

### UFW
 `$ pacman -S ufw `
 `$ ufw default deny `
 `$ ufw allow 80`
 `$ ufw allow 443`
 `$ ufw allow 9418`
 `$ systemctl start ufw.service`
 `$ systemctl enable ufw.service`

### yay:

 `$ pacman -S wget git expac jshon`
 `$ mkdir yay`
 `$ cd yay`
 `$ wget https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=yay`
 `$ mv PKGBUILD?h=yay PKGBUILD`
 `$ makepkg`
 `$ pacman -U yay-<package number>-1-any.pkg.tar.xz`

### Nvidia 

If you have an Nvidia card, see the following link: https://wiki.archlinux.org/title/NVIDIA 

### Remove the nvidia splash screen

Normally when X starts with the nvidia drivers installed, a splash screen is shown. This can be removed by setting the NoLogo option to "true" as shown in the example below.
File: xorg.conf: Disable nvidia splash screen
 
Section "Device"
  Identifier "GeForce2 Pro/GTS"
  Driver     "nvidia"
  VideoRam   65536
  Option     "NoLogo" "true"
EndSection



### DPI and EDID options

Set DPI and EDID in /etc/X11/xorg.conf, under the monitor section:
` Option "DPI" "90x90"`
` Option "UseEdidDpi" "False"`

Run X to confirm Xorg works properly
# startx

************ REBOOT ***************

### Limited shell logins for security
In order to maintain an authenticated session with logind and to prevent bypassing the screen locker by switching terminals, Xorg has to be started on the same virtual terminal where the login occurred. Therefore it is recommended to specify vt$XDG_VTNR in the ~/.xserverrc file:
#~/.xserverrc
#!/bin/sh exec /usr/bin/Xorg -nolisten tcp "$@" vt$XDG_VTNR

Open the file /etc/systemd/logind.conf and set the option NAutoVTs=6 to 1 and uncomment "SessionsMax", then set the value to 1 

### Automatic login to virtual console

Configuration relies on systemd drop-in files to override the default parameters passed to agetty. Note: It has been reported that this method may interfere with the hibernating process. Edit the provided unit either manually by creating the following drop-in snippet, or by running 
# systemctl edit getty@tty1

which will open the file detailed below :

` /etc/systemd/system/getty@tty1.service.d/override.conf`

```
 [Service] 
 ExecStart= 
 ExecStart=-/usr/bin/agetty --autologin username  %I $TERM
```
(Add: --noclear before %I above to keep log output)

Tip: The option Type=idle found in the default getty@.service will delay the service startup until all jobs (state change requests to units) are completed in order to avoid polluting the login prompt with boot-up messages. When starting X automatically, it may be useful to start getty@tty1.serviceimmediately by adding Type=simple into the drop-in snippet. Both the init system and startx can be silenced to avoid the interleaving of their messages during boot-up.
 
 
### QUIET LOGIN

Xinit 

To hide startx messages, you could redirect its output to /dev/null, in your `.bash_profile` like so:

` exec startx -- -keeptty > ~/.xorg.log 2>&1`

Or copy `/etc/X11/xinit/xserverrc` to `~/.xserverrc`, and append -keeptty.

Sysctl

To hide any kernel messages from the console, add or modify the kernel.printk line:

` /etc/sysctl.d/20-quiet-printk.conf`

` kernel.printk = 3 3 3 3`

### Plymouth

`$ yay -S plymouth`

- Edit: /etc/miknitcpio.conf 

- Under the HOOKS section add 'sd-plymouth'. DO NOT USE 'plymouth-encrypt', as per the arch wiki we need to continue using sd-encrypt because this is a systemd initramfs

- We can alter themes by changing the Themes option in /etc/plymouthd/plymouth.conf

After installing, rebuild your initramfs 

`$ sudo mkinitcpio -p linux-lts`

If you are getting a poor resolution, then we either need to add 'i915' to the modules section of mkinitcpio and then rebuild, or enable KMS which is a whole other task in itself


### Automounting:

`$ pacman -S udisks2 udiskie`

Configuration should be ready to go out of the box and running udiskie should already be in the provided `.xinitrc` file in this repo.


### i3blocks:

<to be filled>


### rofi:

<to be filled>


### compton:

<to be filled>


### Linking configs from this repo

Clone this repo into wherever you want, I chose /etc/git/dotfiles
 
 `$ ln -s /etc/git/dotfiles/ArchLinux-Grout/.bash_profile ~/.bash_profile`
 `$ ln -s /etc/git/dotfiles/ArchLinux-Grout/.bashrc ~/.bashrc`
 `$ ln -s /etc/git/dotfiles/ArchLinux-Grout/.config ~/.config`
 `$ ln -s /etc/git/dotfiles/ArchLinux-Grout/X/.xinitrc ~/.xinitrc`


### Vim

Install vim-plug (you won't need to do this if you downloaded the git files linked them as outlined above) 

```$ curl -fLo /etc/git/dotfiles/vim_config/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim```

Link files:
`$ ln -s /etc/git/dotfiles/vim_config/vimrc /etc/vimrc`
`$ ln -s /etc/git/dotfiles/vim_config/.vimrc.plug /etc/.vimrc.plug`

- (Then run :PlugInstall from within vim)

### Development Tools (Optional)

pkg-config

make sure pkg-config is installed and PKG_CONFIG_PATH env variable is set:

`$ echo "export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig:/usr/share/pkgconfig >> /etc/profile`

### OpenCV

Packages: cmake, glew, make, pkg-config, hdf5, vtk, opencv, opencv-samples, base-devel
Set env variables in /etc/profile as detailed above. 
Start with the example project here: https://docs.opencv.org/4.0.1/db/df5/tutorial_linux_gcc_cmake.html

Don’t worry about the variables mentioned in the CMakeLists.txt file, these are set as part of the opencv module for Cmake. See here for clarification: https://stackoverflow.com/questions/48275576/how-to-know-variable-such-as-opencv-in-cmake

