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
# delete old self-compiled kernels
grep -E '^\s+initrd\s+/boot/initrd.img-6' /boot/grub/grub.cfg |
  grep -Eo "img-6\..*-g[0-9a-f]{12}$" |
  sed -e 's,img\-,,' |
  while read -r v; do
    rm /boot/*-${v}
  done
update-grub &>>/root/make.$suffix.log

touch /var/run/reboot-required
ln -snf $PWD /usr/src/linux
rm /root/make.log # indicator that we likely reached this line

if [[ ${2-} == "reboot" ]]; then
  # wait till no ssh connection is open
  while pgrep -af 'sshd:' | grep -v '/usr/sbin/sshd'; do
    sleep 10
  done
  reboot
fi
