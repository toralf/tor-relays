#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf

cd ~/linux

suffix=$(date +%Y%m%d-%H%M%S)

truncate -s 0 /root/make.$suffix.log
rm -f /root/make.log
ln /root/make.$suffix.log /root/make.log

# shellcheck disable=SC2129
make -j ${1:-1} &>>/root/make.$suffix.log
make modules_install &>>/root/make.$suffix.log
make install &>>/root/make.$suffix.log

kver=$(make kernelversion)
lver=$(KERNELVERSION=$kver ./scripts/setlocalversion)
grub_entry="Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux $lver"
sed -i -e "s#^GRUB_DEFAULT=.*#GRUB_DEFAULT=\"$grub_entry\"#" /etc/default/grub
update-grub &>>/root/make.$suffix.log
touch /var/run/reboot-required

ln -snf $PWD /usr/src/linux

rm /root/make.log

if [[ ${2-} == reboot_immediately ]]; then
  reboot
fi
