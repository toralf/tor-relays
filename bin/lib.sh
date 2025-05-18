# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: ./.wellknown entries will not cleaned here

function cleanLocalDataEntries() {
  local d=$(dirname $0)

  echo -e " deleting local entries and facts ..."
  set +e
  while read -r name; do
    [[ -n ${name} ]] || continue
    # Ansible facts
    rm -f $d/../.ansible_facts/${name}
    # entries in ~/tmp
    sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
    # private Tor bridge line
    sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  done < <(xargs -n 1 <<<$*)
  set -e
}

function cleanLocalDataFiles() {
  local d=$(dirname $0)

  echo -e " deleting local data files ..."
  set +e
  while read -r name; do
    # files in ~/tmp subdirs
    rm -f ~/tmp/*/${name} ~/tmp/*/${name}.*
    # client certs
    rm -f $d/../secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  done < <(xargs -n 1 <<<$*)
  set -e
}

function setImageToLatestSnapshotId() {
  # shellcheck disable=SC2154
  while read -r id description; do
    if [[ ${name} =~ ${description} ]]; then
      # shellcheck disable=SC2034
      image=${id}
      break
    fi
  done <<<${snapshots}
}
