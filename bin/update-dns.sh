#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# update /etc/unbound/hetzner-${project}.conf

set -euf
export LANG=C.utf8

project=${1:?}

hconf=/etc/unbound/hetzner-${project}.conf
if ! grep -q "include:.*${hconf}" /etc/unbound/unbound.conf; then
  echo -e "\n unbound does not use ${hconf} ?!\n"
  exit 1
fi

hcloud context use ${project}

# do not run in parallel
if [[ -f ${hconf}.new ]]; then
  echo -n " $(date) found ${hconf}.new, waiting "
  while [[ -e ${hconf}.new ]]
  do
    echo -n '.'
    sleep 2
  done
  date
fi
sudo touch ${hconf}.new

(
  echo 'server:'

  hcloud server list |\
  # ID   NAME   STATUS   IPV4   IPV6   DATACENTER
  awk '! /ID/ { print $2, $4, $5 }' |\
  sort |\
  while read -r name ip4 ip6mask
  do
    ip6=$(sed -e 's,/64,1,' <<< ${ip6mask})   # Debian defaults to [...:1]
    printf "  local-data:     \"%-40s  A     %s\"\n" ${name} ${ip4}
    printf "  local-data:     \"%-40s  AAAA  %s\"\n" ${name} ${ip6}
    printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip4} ${name}
    printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip6} ${name}
  done
) | sudo tee ${hconf}.new 1>/dev/null

# no unneeded reload
if ! diff -q ${hconf}.new ${hconf} 1>/dev/null; then
  sudo cp ${hconf}.new ${hconf}
  sudo /sbin/rc-service unbound reload
fi

sudo rm ${hconf}.new
