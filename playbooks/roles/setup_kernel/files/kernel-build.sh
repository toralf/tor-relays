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

echo -e "\n$(date) config ...\n"
yes '' | make oldconfig # >/dev/null

echo -e "\n$(date) make...\n"
# make clean
make -j $(nproc)
make modules_install
make install

echo -e "\n$(date) grub ...\n"
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
ln -snf ${PWD} /usr/src/linux

echo -e "\n$(date) reboot ...\n"
if [[ ${1-} == "reboot" ]]; then
  i=3
  while ((i--)) && pgrep -af 'sshd:' | grep -v '/usr/sbin/sshd'; do
    echo "finish ssh connections graceful ..."
    sleep 60
  done
  reboot
else
  touch /var/run/reboot-required
fi
