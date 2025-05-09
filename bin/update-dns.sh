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

hash -r hcloud rc-service

[[ $# -eq 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

hconf=/etc/unbound/hetzner-${project}.conf
if ! sudo grep -q -e "^include: \"${hconf}\"" /etc/unbound/unbound.conf; then
  echo "unbound is not configured to use ${hconf}" >&2
  exit 1
fi

echo -e " updating DNS ..."

# do not run in parallel
while [[ -e ${hconf}.new ]]; do
  echo -n '.'
  sleep 1
done

set -o pipefail

echo -e "# managed by $(realpath $0)\nserver:" | sudo tee ${hconf}.new >/dev/null
trap Exit INT QUIT TERM EXIT

hcloud server list --output noheader --output columns=name,ipv4 |
  sort |
  while read -r name ipv4; do
    printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "A" ${ipv4}
    printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ipv4} "" ${name}
    ipv6=$(grep "^${name} " ~/tmp/all_ipv6 2>/dev/null | awk '{ print $2 }')
    if [[ -n ${ipv6} ]]; then
      printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "AAAA" ${ipv6}
      printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ipv6} "" ${name}
    fi
  done |
  sudo tee -a ${hconf}.new >/dev/null

if ! sudo diff -q ${hconf} ${hconf}.new 1>/dev/null; then
  sudo cp ${hconf}.new ${hconf}
  echo " reloading DNS resolver"
  sudo rc-service unbound reload
else
  echo " no changes in ${hconf}"
fi
