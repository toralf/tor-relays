#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -eq 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

hconf=/etc/unbound/hetzner-${project}.conf

# do not run this script parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done
echo "# managed by $(realpath $0)" | sudo tee ${hconf}.new 1>/dev/null

if ! sudo grep -q "include:.*${hconf}" /etc/unbound/unbound.conf; then
  echo -e "\n unbound does not use ${hconf} ?!\n"
  exit 1
fi

# update /etc/unbound/hetzner-${project}.conf
(
  echo 'server:'

  hcloud server list |
    # ID   NAME   STATUS   IPV4   IPV6   DATACENTER
    awk '! /ID/ { print $2, $4, $5 }' |
    sort |
    while read -r name ip4 ip6mask; do
      ip6=$(sed -e 's,/64,1,' <<<${ip6mask}) # Debian defaults to [...:1]
      printf "  local-data:     \"%-40s  A     %s\"\n" ${name} ${ip4}
      printf "  local-data:     \"%-40s  AAAA  %s\"\n" ${name} ${ip6}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip4} ${name}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip6} ${name}
    done
) | sudo tee -a ${hconf}.new 1>/dev/null

if ! sudo diff ${hconf}.new ${hconf}; then
  echo " update unbound config ..."
  sudo mv ${hconf}.new ${hconf}
  sudo rc-service unbound reload
else
  sudo rm ${hconf}.new
fi
