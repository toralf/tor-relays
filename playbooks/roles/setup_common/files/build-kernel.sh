#!/bin/bash
# set -x

set -euf

cd ~/linux

suffix=$(date +%Y%m%d-%H%M%S)

make -j ${1:-1} &>/root/make.$suffix.log
make modules_install &>/root/make-modules_install.$suffix.log
make install &>/root/make-install.$suffix.log

kver=$(make kernelversion)
lver=$(KERNELVERSION=$kver ./scripts/setlocalversion)
grub_entry="Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux $lver"
sed -i -e "s#^GRUB_DEFAULT=.*#GRUB_DEFAULT=\"$grub_entry\"#" /etc/default/grub
update-grub &>/root/make-grub.$suffix.log
touch /var/run/reboot-required

ln -snf $PWD /usr/src/linux

if [[ ${2-} == reboot_immediately ]]; then
  reboot
fi
