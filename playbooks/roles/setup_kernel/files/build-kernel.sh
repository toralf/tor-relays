#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -eu # no -f

cd ~/linux

suffix=$(date +%Y%m%d-%H%M%S)

truncate -s 0 ~/make.${suffix}.log
ln -sf ~/make.${suffix}.log ~/make.log

exec 1>~/make.log
exec 2>&1

# shellcheck disable=SC2129
# make clean
make -j $(nproc)
make modules_install
make install

kver=$(make kernelversion)
lver=$(KERNELVERSION=${kver} ./scripts/setlocalversion)
grub_entry="Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux ${lver}"
sed -i -e "s#^GRUB_DEFAULT=.*#GRUB_DEFAULT=\"${grub_entry}\"#" /etc/default/grub
# delete old self-compiled kernels
grep -E '^\s+initrd\s+/boot/initrd.img-6\..*-g[0-9a-f]{12}$' /boot/grub/grub.cfg |
  awk '{ print $2 }' |
  sed -e 's,.*img\-,,' |
  sort -u |
  grep -v ${lver} |
  while read -r i; do
    rm /boot/*-${i}
  done
rm -f /boot/*-6.*-g[0-9a-f]*.old /boot/vmlinuz.old
update-grub

touch /var/run/reboot-required
ln -snf ${PWD} /usr/src/linux

if [[ ${2-} == "reboot" ]]; then
  if pgrep -af 'sshd:' | grep -v '/usr/sbin/sshd'; then
    service ssh stop
    sleep 180
  fi
  reboot
fi
