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

[[ $# -eq 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

hconf=/etc/unbound/hetzner-${project}.conf

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

  hcloud server list --output columns=name,ipv4,ipv6 |
    grep -v '^NAME' |
    sort |
    while read -r name ip4 ip6mask; do
      ip6="${ip6mask%/*}1" # Debian defaults to [...:1]
      printf "  local-data:     \"%-40s  A     %s\"\n" ${name} ${ip4}
      printf "  local-data:     \"%-40s  AAAA  %s\"\n" ${name} ${ip6}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip4} ${name}
      printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip6} ${name}
    done
) | sudo tee -a ${hconf}.new 1>/dev/null

if ! sudo diff ${hconf}.new ${hconf}; then
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
fi
