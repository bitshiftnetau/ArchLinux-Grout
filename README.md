BUILDING ARCH MACHINE: UEFI-GPT, LTS kernel, Systemd initramfs, LUKS on LVM, and rEFInd

First some overview of this system architecture. Some of this guide is taken from the Arch Linux Wiki so feel free to compare notes.

We are using rEFInd because gummitboot (systemd-boot) has some limitation pertanent to this system configuration. UEFI-GPT because we don't live in the dark ages. Sytemd initramfs and not BusyBox for the same reasons. As for the style of disk encryption, I considered using LVM on Luks (individually encrypted partitions), but I'm lazy af and I don't want to use GRUB2.

The desktop will consist of Xorg (because I couldn't get Weston to work so fuck it), with a custom openbox config, conky running all kinds of system metrics, tint2 for the tray, and tilda for the main terminal. This desktop config kind of revolves around the use of tilda, so I am calling this configuration "Swinton" because she is god-damn amazing in literally every role she has ever had. Hail Satan.

....begin

- Download Arch ISO

- Zero out the usb first with dd. Otherwise if there are any partitions on the usb, dd will create another partition and fuck your shit up.

- dd image onto usb

- boot arch and select UEFI usb from the BIOS menu

- connect to wifi select wireless 
# wifi-menu

- or just use ethernet
# ip link set eth0/enp4s0 up

- run up dhcpcd to get ip addr
# dhcpd eth0/wlpXsX

- find the device name of desired installation target
# fdisk -l

- zero out disk:
# dd if=/dev/zero of=/dev/DEVICENAME

GPT & LVM inside LUKS (encrypted LVM)

Prepare the disk for encryption using dm-crypt wipe on an empty disk or partition

- First, create a temporary encrypted container on the partition (using the form sdXY) or complete device (using the form sdX) to be encrypted:
# cryptsetup open --type plain -d /dev/urandom /dev/<block-device> disk_clean

- You can verify that it exists:
# lsblk

NAME          MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda             8:0    0  1.8T  0 disk
└─to_be_wiped 252:0    0  1.8T  0 crypt

- Wipe the container with zeros. A use of if=/dev/urandom is not required as the encryption cipher is used for randomness.
# dd if=/dev/zero of=/dev/mapper/disk_clean bs=1M status=progress

To perform a check of the operation, zero the partition before creating the wipe container. After the wipe command blockdev --getsize64 /dev/mapper/container can be used to get the exact container size as root. Now od can be used to spotcheck whether the wipe overwrote the zeroed sectors, e.g. od -j containersize - blocksize to view the wipe completed to the end.

- Finally, close the temporary container:
# cryptsetup close disk_clean

- Parition your disk
# fdisk /dev/sdX
# g (new GPT partition table)
# n (new)
# p (primary... could be extended or wateva suits)

- sector start xxxx (refer to table below)
- sector end xxxx (refer to table below)

- Your partition layout should look like this:

- Number       Start(sector)     End(sector)     Size        Code Name 
- 1            2048              1130495         550.0 MiB   EF00 EFI System 
- 2            1130496           69205982        32.3 GiB    8E00 Linux LVM

- Create the LUKS encrypted container at the "system" partition.
# cryptsetup luksFormat --type luks2 /dev/sda4

For more information about the available cryptsetup options see the LUKS encryption options prior to above command.

- Open the partition into a cryptcontainer, give the container a name, and assign it to the crypt mapper (btw, you will need to do this before mounting a partition if you boot a recovery usb):
# cryptsetup open /dev/sda4 cryptlvm

The decrypted container is now available at /dev/mapper/cryptlvm.

Preparing the logical volumes

- Create a physical volume on top of the opened LUKS container:
# pvcreate /dev/mapper/cryptlvm

- Create the volume group named MyVolGroup (or whatever you want), adding the previously created physical volume to it:
# vgcreate VolGroup00 /dev/mapper/cryptlvm

- Create all your logical volumes on the volume group:
# lvcreate -L 20G VolGroup00 -n lvolroot 
# lvcreate -L 12G VolGroup00 -n lvolvar 
# lvcreate -l 100%FREE VolGroup00 -n lvolhome

- Format your filesystems on each logical volume:
# mkfs.ext4 /dev/MyVolGroup/root 
# mkfs.ext4 /dev/MyVolGroup/home 
# mkfs.ext4 /dev/MyVolGroup/var
# mkfs.vfat /dev/sda1

Notice how we are accessing the volumes through the volume group and not through the cryptmapper. That is because we are accessing the logical volumes, not the underlying luks crypto-container.

- Mount your filesystem:
# mount /dev/MyVolGroup/lvolroot /mnt 
# mkdir /mnt/home
# mkdir /mnt/var
# mkdir /mnt/boot
# mount /dev/MyVolGroup/lvolhome /mnt/home
# mount /dev/MyVolGroup/lvolvar /mnt/var 
# mount /dev/sda1 /mnt/boot

Snapshots (Optional)

LVM allows you to take a snapshot of your system in a much more efficient way than a traditional backup. It does this efficiently by using a COW (copy-on-write) policy. The initial snapshot you take simply contains hard-links to the inodes of your actual data. So long as your data remains unchanged, the snapshot merely contains its inode pointers and not the data itself. Whenever you modify a file or directory that the snapshot points to, LVM automatically clones the data, the old copy referenced by the snapshot, and the new copy referenced by your active system. Thus, you can snapshot a system with 35 GiB of data using just 2 GiB of free space so long as you modify less than 2 GiB (on both the original and snapshot). In order to be able to create snapshots you need to have unallocated space in your volume group. Snapshot like any other volume will take up space in the volume group. So, if you plan to use snapshots for backing up your root partition do not allocate 100% of your volume group for root logical volume.

System Configuration

- You create snapshot logical volumes just like normal ones.
# lvcreate --size 100M --snapshot --name snap01 /dev/VolGroup00/lvolboot-snap01

- Reverting the modified 'lv' logical volume to the state when the 'snap01' snapshot was taken can be done with
# lvconvert --merge /dev/VolGroup00/lvolboot-snap01

Read more about LVM snapshots here: https://wiki.archlinux.org/index.php/LVM#Snapshots 
And more about creating root snapshots here: https://wiki.archlinux.org/index.php/Create_root_filesystem_snapshots_with_LVM

-------- Install the base packages ----------

- Use the pacstrap script to install the base group:
# pacstrap /mnt base base-devel (for AUR repos)

- If the installation is broken by an old signature on an old installation media, then just run 
# pacman-key --refresh-keys

Whilst rooted on the installation media and it should be fine.

- Generate an fstab file (if you use UUIDs, make sure they are the PARTUUIDs not the physical UUIDs)
# genfstab -p /mnt >> /mnt/etc/fstab

- root into new system: 
#arch-chroot /mnt /bin/bash

UPDATE MICROCODE
For AMD processors the microcode updates are available in linux-firmware, which is installed as part of the base system. No further action is needed.
For Intel processors, install intel-ucode and continue reading.

Enabling Intel microcode updates
Microcode must be loaded by the bootloader. Because of the wide variability in users' early-boot configuration, Intel microcode updates may not be triggered automatically by Arch's default configuration. Many AUR kernels have followed the path of the official Arch kernels in this regard.

These updates must be enabled by adding /boot/intel-ucode.img as the first initrd in the bootloader config file. This is in addition to the normal initrd file. See below for instructions using rEFInd

SWITCHING TO LTS KERNEL

- Install linux-lts kernel:
# pacman -R linux
# pacman -S linux-lts

Configure initramfs

- If /etc/vconsole.conf doesn't exist:
# touch /etc/vconsole.conf

- Edit mkinitcpio.conf
# nano /etc/mkinitcpio.conf

Remove these from HOOKS: udev, lvm2

- add these to HOOKS:
# systemd filsystems keyboard sd-vconsole sd-encrypt sd-lvm2 mdadm_udev

Generate initramfs using lts kernel and the new hooks:
# mkinitcpio -p linux-lts

SETTING THE LOCALES

Edit locale.gen:
# nano /etc/locale.gen

Uncomment the following lines:
# en_US.UTF-8 UTF-8

Set the time zone:
# ln -sf /usr/share/zoneinfo/zone/subzone /etc/localtime

Before locales can be enabled, they must be generated:
# locale-gen

Set the locale permanently:
# echo LANG=en_US.UTF-8 > /etc/locale.conf

Export the chosen locale:
# export LANG=en_US.UTF-8

To set the hardware clock to UTC in Linux, run:
# hwclock --systohc --utc

Set the hostname to your liking:
# echo <myhostname> > /etc/hostname

Add the same hostname to /etc/hosts:
# 127.0.0.1 localhost 
# ::1 localhost 
# 127.0.1.1 myhostname.localdomain myhostname

SET PASSWORD OF ROOT:
# passwd

Install wireless
# pacman -S dialog wpa_supplicant

Kernel options
If the root file system resides in a logical volume, the root= kernel parameter must be pointed to the mapped device, e.g /dev/vg-name/lv-name.
Configure /etc/mkinitcpio.conf if additional features are needed. Create a new initial RAM disk with:
# mkinitcpio -p linux-lts (if it doesn’t automatically run after installing the new kernel)

rEFInd

For the following section 'esp' = /boot partition ('esp' simply stands for EFI System Partition. This is the same on the wiki so just take note of that. A little bit misleading tbh but there it is)

Install refind tools:
# pacman -S refind-efi sbsigntools imagemagick parted

Installation with refind-install script

The rEFInd package includes the refind-install script to simplify the process of setting rEFInd as your default EFI boot entry. The script has several options for handling differing setups and UEFI implementations. See refind-install(8) or read the comments in the install script for explanations of the various installation options.

For many systems it should be sufficient to simply run:
# refind-install

This will attempt to find and mount your ESP, copy rEFInd files to esp/EFI/refind/, and use efibootmgr to make rEFInd the default EFI boot application.

When refind-install is run in chroot (e.g. in live system when installing Arch Linux) /boot/refind_linux.conf is populated with kernel options from the live system not the one on which it is installed. You will need to edit /boot/refind_linux.conf and adjust the kernel options manually. See #refind_linux.conf for an example.

refind_linux.conf

If rEFInd automatically detects your kernel, you can place a refind_linux.conf file containing the kernel parameters in the same directory as your kernel. You can use /usr/share/refind/refind_linux.conf-sample as a starting point. We're gonna butcher this file because it doesn't suit our needs at all. 

# nano /boot/refind_linux.conf

- "Runlevel 5: Linux-lts" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts.img rw"

- "Runlevel 5: Linux-lts-fallback" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts-fallback.img rw"

- "Runlevel 3: Drop to terminal" "rd.luks.name=<PART-UUID>=cryptlvm rootfstype=ext4 root=/dev/VolGroup00/lvolroot resume=/dev/VolGroup00/lvolroot initrd=intel-ucode.img initrd=initramfs-linux-lts-fallback.img ro systemd.unit=rescue.target"

Then we need to send through some extra kernel options in /boot/EFI/refind/refind.conf, uncomment the following lines:

# extra_kernel_version_strings linux,linux-hardened,linux-lts,linux-zen,linux-git;
# fold_linux_kernels false

---------------------------------------------------------
*********************************************************
WARNING: reboot into system and post-install from there. 
DO NOT post-install from the live usb!!!
*********************************************************
---------------------------------------------------------

Initialize pacman:

# pacman-key --init
# pacman-key --populate archlinux 

If you are still having problems with pacman after that then create these folders:
# mkdir -p /var/lib/pacman/
# mkdir -p /var/cache/pacman/pkg
# mkdir -p /var/log

INSTALL SUDO (SUDO_CONFIG)
# pacman -S sudo

INSTALL UFW
# pacman -S ufw 
# ufw default deny 
# ufw allow 80
# ufw allow 443
# ufw allow 9418
# systemctl start ufw.service
# systemctl enable ufw.service


At this point I usually install an AUR helper and a vpn client. My poison of choice is packer, as for VPNs I use expressvpn. 

Packer:

# pacman -S wget git expac jshon
# mkdir packer
# cd packer
# wget https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=packer
# mv PKGBUILD?h=packer PKGBUILD
# makepkg
# pacman -U packer-20150808-1-any.pkg.tar.xz

Expressvpn:

# packer -s expressvpn
# systemctl start expressvpn.service
# expressvpn activate (there is an activation code in your account on your user dashboard)
# expressvpn list
# expressvpn connect [id]

[id] is optional, you can simply auto-connect to the smart-location by omitting [id]

Navigate out of the temporary installation directory.
# cd ..

Clean up by removing the temporary installation directory.
# rm -dR packer

Nvidia 

If you have an Nvidia card, install the nvidia or nouveau drivers: 

# pacman -S nvidia-3**xx-lts

touch /etc/modprobe.d/blacklist.conf
# blacklist nouveau

generate a config file:
# nvidia-xconfig

config file can be found at /etc/X11/xorg.conf

Xorg
# pacman -S xorg xorg-xinit xterm

Video Drivers:
# xf86-video-fbdev & xterm

Set DPI and EDID in /etc/X11/xorg.conf, under the monitor section:
# Option "DPI" "90x90"
# Option "UseEdidDpi" "False"

In order to maintain an authenticated session with logind and to prevent bypassing the screen locker by switching terminals, Xorg has to be started on the same virtual terminal where the login occurred. Therefore it is recommended to specify vt$XDG_VTNR in the ~/.xserverrc file:
#~/.xserverrc
#!/bin/sh exec /usr/bin/Xorg -nolisten tcp "$@" vt$XDG_VTNR

Run X
# startx

************ REBOOT ***************

Login Security

Open the file /etc/systemd/logind.conf and set the option NAutoVTs=6 to 1 and uncomment "SessionsMax", then set the value to 1 


Automatic login to virtual console

Configuration relies on systemd drop-in files to override the default parameters passed to agetty. Note: It has been reported that this method may interfere with the hibernating process. Edit the provided unit either manually by creating the following drop-in snippet, or by running 
# systemctl edit getty@tty1

which will open the file detailed below :

# /etc/systemd/system/getty@tty1.service.d/override.conf

# [Service] 
# ExecStart= 
# ExecStart=-/usr/bin/agetty --autologin username  %I $TERM
(Add: --noclear before %I above to keep log output)

Tip: The option Type=idle found in the default getty@.service will delay the service startup until all jobs (state change requests to units) are completed in order to avoid polluting the login prompt with boot-up messages. When starting X automatically, it may be useful to start getty@tty1.serviceimmediately by adding Type=simple into the drop-in snippet. Both the init system and startx can be silenced to avoid the interleaving of their messages during boot-up.
 
 
QUIET LOGIN

Xinit 

- NOTE: This is already in the 

To hide startx messages, you could redirect its output to /dev/null, in your .bash_profile like so:

# exec startx -- -keeptty > ~/.xorg.log 2>&1

Or copy /etc/X11/xinit/xserverrc to ~/.xserverrc, and append -keeptty.

Sysctl

To hide any kernel messages from the console, add or modify the kernel.printk line:

# /etc/sysctl.d/20-quiet-printk.conf

# kernel.printk = 3 3 3 3

- Plymouth

# packer -S plymouth

#/etc/miknitcpio.conf 

- Under the HOOKS section add 'sd-plymouth'. DO NOT USE 'plymouth-encrypt', as per the arch wiki we need to continue using sd-encrypt because this is a systemd initramfs

We can alter themes by changing the Themes option in /etc/plymouthd/plymouth.conf

After installing, rebuild your initramfs 

# sudo mkinitcpio -p linux-lts

If you are getting a poor resolution, then we either need to add 'i915' to the modules section of mkinitcpio and then rebuild, or enable KMS which is a whole other task in itself


Building the desktop

Core packages

- tint2 
- conky 
- conky-manager
- clipmenu
- compton
- tilda
- nitrogen
- vim
- obconf
- gtk-vmc
- pcmanfm
- firefox / chromium
- udisks2 & udiskie
- gtk-engines

AUR
obmenu-generator
expressvpn
conky-lua-nv

Setup:
plymouth
conky
xorg
doxygen
ctags
vim 
vim-ale
ufw
udiskie
tor
tilda
tint2
splint
php
mariadb
apache (with php as well)
phpmyadmin
redshift
openbox
opencv
chromium
firefox
compton
git
lxappearance
 
npm:
nodemon
 
Install package list from text file: 
# pacman -S --needed - < pkg-list.txt

Install package list from text file with packages commented out, or comments after package in list:
# sed -e "/^#/d" -e "s/#.*//" pkg-list.txt | pacman -S --needed - < pkg-list.txt

Pull down config files/folders to /etc/git/dotfiles/…

- vim_config (optional)
- .config
- .conky
- .bash_profile 
- .bash_rc
- .xinitrc

Link files:
- ln -s /etc/git/dotfiles/.bash_profile ~/.bash_profile
- ln -s /etc/git/dotfiles/.bashrc ~/.bashrc
- ln -s /etc/git/dotfiles/.config ~/.config
- ln -s /etc/git/dotfiles/conky/.conky ~/.conky
- ln -s /etc/git/dotfiles/X/.xinitrc ~/.xinitrc

FONTS:
- ttf-dejavu (for GUI programs)
- xorg-fonts-100dpi (DEC Terminal)
- xorg-fonts-75dpi
- ttf-liberation (to actually render pdfs in Chromium)

For default system font it's DEC Terminal. However, seeing as that font only accounts for certain font sizes we are also installing ttf-dejavu to act as our fallback font in things like web browsers and pdf documents. 

Remove the nvidia splash screen

Normally when X starts with the nvidia drivers installed, a splash screen is shown. This can be removed by setting the NoLogo option to "true" as shown in the example below.
File: xorg.conf: Disable nvidia splash screen
 
Section "Device"
  Identifier "GeForce2 Pro/GTS"
  Driver     "nvidia"
  VideoRam   65536
  Option     "NoLogo" "true"
EndSection

AUTOMOUNTING:

pacman -S udisks2 udiskie
configuration should be ready to go out of the box and running udiskie should already be in the provided .xinitrc file.

*****************************************************************************************
*****************************************************************************************
At this point, feel free to reboot the system and enjoy. If you have any issues
please don't hesitate to email me at admin@bitshift.net.au however please consider 
reading through this post again, before contacting.
*****************************************************************************************
*****************************************************************************************

Vim

Install vim-plug (you won't need to do this if you downloaded the git files linked them as outlined above) 

curl -fLo /etc/git/dotfiles/vim_config/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

Link files:
# ln -s /etc/git/dotfiles/vim_config/vimrc /etc/vimrc
# ln -s /etc/git/dotfiles/vim_config/.vimrc.plug /etc/.vimrc.plug

- (Then run :PlugInstall from within vim)

Development Tools (Optional)

- pkg-config

make sure pkg-config is installed and PKG_CONFIG_PATH env variable is set:

# echo "export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig:/usr/share/pkgconfig >> /etc/profile

OpenCV

Packages: cmake, glew, make, pkg-config, hdf5, vtk, opencv, opencv-samples, base-devel
Set env variables in /etc/profile as detailed above. 
Start with the example project here: https://docs.opencv.org/4.0.1/db/df5/tutorial_linux_gcc_cmake.html

Don’t worry about the variables mentioned in the CMakeLists.txt file, these are set as part of the opencv module for Cmake. See here for clarification: https://stackoverflow.com/questions/48275576/how-to-know-variable-such-as-opencv-in-cmake

PHP
Install LAMP stack according to this:
- https://www.ostechnix.com/install-apache-mariadb-php-lamp-stack-on-arch-linux-2016/

link (all) /srv/code/php/<project name> folders to /srv/http/<project name>
# chown -R root:access /srv/code
# chmod -R 775 /srv/code

Optimizing Openbox

Open up /usr/lib/openbox/openbox-autostart and comment out everything except the parts relevant to launching a local config file. 

If you aren't using xdg-autostart then comment out that line as well. 



