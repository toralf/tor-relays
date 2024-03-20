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

hash -r hcloud

[[ $# -le 1 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

hconf=/etc/unbound/hetzner-${project}.conf
if ! sudo grep -q ${hconf} /etc/unbound/unbound.conf; then
  echo "unbound is not configured to use ${hconf}" >&2
  exit 1
fi

# do not change the resolver config file in parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done
echo -e "# managed by $(realpath $0)\nserver:" | sudo tee ${hconf}.new >/dev/null
trap Exit INT QUIT TERM EXIT

hcloud server list --output columns=name,ipv4 |
  grep -v '^NAME' |
  sort |
  while read -r name ipv4; do
    printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "A" ${ipv4}
    printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ipv4} "" ${name}
  done |
  sudo tee -a ${hconf}.new >/dev/null

if ! sudo diff -q ${hconf} ${hconf}.new; then
  echo " reloading DNS resolver" >&2
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
else
  echo " no changes in ${hconf}" >&2
fi
