# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: ./.wellknown entries will not cleaned here

function cleanLocalDataEntries() {
  echo -e " deleting local entries and facts ..."
  local files
  files=$(find ~/tmp/tor-relays/ -maxdepth 1 -type f)
  set +e
  while read -r name; do
    [[ -n ${name} ]] || continue
    # Ansible facts
    rm -f $(dirname $0)/../.ansible_facts/${name}
    # line in files under {{ tmp_dir }}
    sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/\[\"${name}:[0-9]*\"\]/d" ${files} 2>/dev/null
    # private Tor bridge lines
    sed -i -e "/ # ${name}$/d" /tmp/tor-relays/*_bridgeline 2>/dev/null
  done < <(xargs -n 1 <<<$*)
  set -e
}

function cleanLocalDataFiles() {
  echo -e " deleting local data files ..."
  set +e
  while read -r name; do
    [[ -n ${name} ]] || continue
    # certain files in {{ tmp_dir }} subdirs
    rm -f ~/tmp/tor-relays/{coredump,ddos,ddos6,dmesg,kconfig}/${name}{,.*}
    # client certs
    rm -f $(dirname $0)/../secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  done < <(xargs -n 1 <<<$*)
  set -e
}

function setProject() {
  project=$(hcloud context active)
  echo -e "\n >>> using Hetzner project \"${project:?NO PROJECT FOUND}\""
}

function getSnapshots() {
  hcloud --quiet image list --type snapshot --output noheader --output columns=description,id |
    awk '{ if (NF == 2) { print } }' |
    sort -r -n
}

function getImage() {
  if [[ ${LOOKUP_SNAPSHOT-} == "n" ]] || ! _getImageBySnapshot ${name}; then
    _getImageByHostname ${name}
  fi
}

function _getImageByHostname() {
  local name

  name=${1?NAME NOT GIVEN}
  # name example: hi-u-amd-master
  if [[ ${name} =~ "-db-" ]]; then
    echo "debian-12"
  elif [[ ${name} =~ "-dt-" ]]; then
    echo "debian-13"
  elif [[ ${name} =~ "-un-" ]]; then
    echo "ubuntu-24.04"
  else
    echo ${HCLOUD_FALLBACK_IMAGE:-"debian-12"}
  fi
}

function _getImageBySnapshot() {
  local name description id

  name=${1?NAME NOT GIVEN}
  if [[ -z ${snapshots} ]]; then
    echo " * * * snapshots NOT SET" >&2
    return 1
  fi

  # prefer "hi-u-intel-stablerc" to match "u-intel-stablerc" but otherwise to match "u-intel-stable"
  # name=$(sed -e 's,stablerc,ltsrc,' <<<${name}) # tweak to reuse an existing snapshot

  while read -r description id; do
    if [[ ${name} =~ -${description}$ || ${name} =~ -${description}- || ${HCLOUD_FALLBACK_IMAGE-} == "${description}" ]]; then
      echo ${id}
      return 0
    fi
  done <<<${snapshots}

  while read -r description id; do
    if [[ ${name} =~ -${description} ]]; then
      echo ${id}
      return 0
    fi
  done <<<${snapshots}

  return 1
}
