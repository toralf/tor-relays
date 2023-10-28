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

hash -r unbound

[[ $# -le 1 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

hconf=/etc/unbound/hetzner-${project}.conf
if ! sudo grep -q ${hconf} /etc/unbound/unbound.conf; then
  echo "unbound is not configured to use ${hconf}" >&2
  exit 1
fi

# do not change the resolver file in parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done
echo "# managed by $(realpath $0)" | sudo tee ${hconf}.new >/dev/null
trap Exit INT QUIT TERM EXIT

(
  echo 'server:'

  hcloud server list --output columns=name,ipv4,ipv6 |
    grep -v '^NAME' |
    sort -n |
    while read -r name ipv4 ipv6; do
      # IPv4
      printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "A" ${ipv4}
      printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ipv4} "" ${name}
      # IPv6
      ipv6_address=$(sed -e 's,/64,1,' <<<$ipv6)
      printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "AAAA" ${ipv6_address}
      printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ipv6_address} "" ${name}
    done
) | sudo tee -a ${hconf}.new >/dev/null

if ! sudo diff ${hconf} ${hconf}.new; then
  echo -e "\n reloading DNS resolver" >&2
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
else
  echo " no DNS changes for ${hconf}" >&2
fi
