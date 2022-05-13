#!/bin/bash
# set -x

# update /etc/unbound/hetzner-${project}.conf

set -euf
export LANG=C.utf8

project=${1:?}
hcloud context use ${project}

if ! grep -q /etc/unbound/hetzner-${project}.conf /etc/unbound/unbound.conf; then
  echo "unbound has to be configured to include thw config file hetzner-${project}.conf"
  exit 1
fi

tmpfile=$(mktemp /tmp/$(basename $0)_XXXXXX)

hcloud server list |\
# ID   NAME   STATUS   IPV4   IPV6   DATACENTER
awk ' !/ID/ { print $2, $4, $5 } ' |\
sort |\
while read -r name ip4 ip6mask
do
  ip6=$(sed -e 's,/64,1,' <<< ${ip6mask})   # Debian defaults to the first ipv6 address ...:1
  printf "  local-data:     \"%-40s  A     %s\"\n" ${name} ${ip4}
  printf "  local-data:     \"%-40s  AAAA  %s\"\n" ${name} ${ip6}
  printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip4} ${name}
  printf "  local-data-ptr: \"%-40s        %s\"\n" ${ip6} ${name}
done > ${tmpfile}

sudo bash -c "
  echo 'server:' >  /etc/unbound/hetzner-${project}.conf
  chmod 644         /etc/unbound/hetzner-${project}.conf
  cat ${tmpfile} >> /etc/unbound/hetzner-${project}.conf
  sudo rc-service unbound reload
"

rm ${tmpfile}
