# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: wellknown entries are not cleaned here
function cleanLocalData() {
  local d=$(dirname $0)

  echo -e " deleting local system data, DNS and ssl ..."
  while read -r name; do
    [[ -n ${name} ]] || continue
    # Ansible facts
    rm -f $d/../.ansible_facts/${name}
    # data in ~/tmp
    sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
    rm -f ~/tmp/*/${name} ~/tmp/*/${name}.*
    # certs
    rm -f $d/../secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
    # private Tor bridge data
    sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  done < <(xargs -n 1 <<<$*)
}
