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

ipv="ipv4"
if [[ ${1-} == '-6' ]]; then
  ipv="ipv6"
fi

hconf=/etc/unbound/hetzner-${project}-${ipv}.conf
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
    while read -r name ip4 ip6; do
      if [[ ${ipv} == "ipv4" ]]; then
        printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "A" ${ip4}
        printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ip4} "" ${name}
      elif [[ ${ipv} == "ipv6" ]]; then
        # get the current IPv6 address
        if ip6=$(
          set -o pipefail
          ssh -4 -n ${name} 'ip -6 a' | awk '/inet6 .* scope global/ { print $2 }' | cut -f 1 -d '/' -s
        ); then
          prefix=$(sed -e 's,:/64,,' <<<$ip6)
          if [[ -n ${ip6} && ${ip6} =~ ${prefix} ]]; then
            printf "  local-data:     \"%-40s  %-4s  %s\"\n" ${name} "AAAA" ${ip6}
            printf "  local-data-ptr: \"%-40s  %-4s  %s\"\n" ${ip6} "" ${name}
          else
            echo " something wrong: '${name}' '${ip6}' '${prefix}'" >&2
          fi
        else
          echo " something wrong: '${name}' '${ip6}'" >&2
        fi
      fi
    done
) | sudo tee -a ${hconf}.new >/dev/null

if ! sudo diff ${hconf} ${hconf}.new; then
  sudo cp ${hconf}.new ${hconf}
  sudo rc-service unbound reload
else
  echo " no DNS changes for ${hconf}" >&2
fi
