#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

function Exit() {
  trap - INT QUIT TERM EXIT
  sudo rm -f ${hconf}.new
}

#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

project=${1?project is missing}

hconf=/etc/unbound/hetzner-${project}.conf

if ! sudo grep -q "include:.*${hconf}" /etc/unbound/unbound.conf; then
  echo -e "\n unbound does not use ${hconf} ?!\n"
  exit 1
fi

trap Exit INT QUIT TERM EXIT

# do not run this script parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done
echo "# managed by $(realpath $0)" | sudo tee ${hconf}.new 1>/dev/null

# update /etc/unbound/hetzner-${project}.conf
(
  echo 'server:'

  hcloud server list |
    # ID   NAME   STATUS   IPV4   IPV6   DATACENTER
    awk '! /ID/ { print $2, $4, $5 }' |
    sort |
    while read -r name ip4 ip6mask; do
      ip6="${ip6mask%/*}1" # Debian defaults to [...:1]
      printf "  local-data:     \"%-40s  A     %s\"\n" ${name} ${ip4}
      printf "  local-data:     \"%-40s  AAAA  %s\"\n" ${name} ${ip6}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip4} ${name}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip6} ${name}
    done
) | sudo tee -a ${hconf}.new 1>/dev/null

if ! sudo diff -q ${hconf}.new ${hconf} 1>/dev/null; then
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
fi
