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

[[ $# -eq 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

hconf=/etc/unbound/hetzner-${project}.conf
if ! sudo grep -q ${hconf} /etc/unbound/unbound.conf; then
  echo "unbound is not configured to use ${hconf}" >&2
  exit 1
fi

# do not change this file in parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done
echo "# managed by $(realpath $0)" | sudo tee ${hconf}.new >/dev/null
trap Exit INT QUIT TERM EXIT

(
  echo 'server:'

  hcloud server list --output columns=name,ipv4 |
    grep -v '^NAME' |
    sort |
    while read -r name ip4; do
      printf "  local-data:     \"%-20s  A     %s\"\n" ${name} ${ip4}
      printf "  local-data-ptr: \"%-20s        %s\"\n" ${ip4} ${name}
    done
) | sudo tee -a ${hconf}.new >/dev/null

if ! sudo diff ${hconf} ${hconf}.new; then
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
else
  echo " no DNS changes for ${hconf}" >&2
fi
