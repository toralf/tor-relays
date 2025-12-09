# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: ./.wellknown entries will not cleaned here

function cleanLocalDataEntries() {
  local files

  echo -e " deleting local entries and facts ..."
  files=$(find ~/tmp/tor-relays/ -maxdepth 1 -type f)
  set +e
  while read -r name; do
    [[ -n ${name} ]] || continue
    rm -f ./.ansible_facts/{,s1_}${name}
    sed -i \
      -e "/^${name}$/d" \
      -e "/^${name} /d" \
      -e "/ ${name}$/d" \
      -e "/ ${name} /d" \
      -e "/\[\"${name}:[0-9]*\"\]/d" \
      ${files} 2>/dev/null
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
    rm -f ~/tmp/tor-relays/{coredump,ddos,ddos6,dmesg,kconfig,trace}/${name}{,.*}
    # client certs
    rm -f ./secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  done < <(xargs -n 1 <<<$*)
  set -e
}

# project is a global variable
function setProject() {
  project=$(hcloud context active)
  echo -e "\n >>> using Hetzner project \"${project?NO PROJECT FOUND}\""
}

function getSnapshots() {
  hcloud --quiet image list --type snapshot --output noheader --output columns=description,id |
    awk '{ if (NF == 2) { print } }' |
    sort -r -n
}

function setImage() {
  if [[ ${LOOKUP_SNAPSHOT-} == "n" || -z ${snapshots} ]] || ! _setImageBySnapshot ${name}; then
    _setImageByHostname ${name}
  fi
}

function _setImageByHostname() {
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
    echo ${HCLOUD_FALLBACK_IMAGE:-"debian-13"}
  fi
}

# examples for match ordering e.g. for hi-dt-intel-stablerc or hs0-dt-intel-stablerc-bp-cl-89
#   dt-intel-stablerc
#   dt-intel-stable
#   dt-x86-stablerc
#   dt-x86-stable
function _setImageBySnapshot() {
  local name altname description id

  name=${1?NAME NOT GIVEN}
  altname=$(sed -e 's,-amd,-x86,' -e 's,-intel,-x86,' <<<${name})

  for n in $(echo ${name} ${altname} | xargs -n 1 | sort -u | xargs); do
    while read -r description id; do
      if [[ -z ${description} ]]; then
        continue
      fi
      if [[ ${n} =~ -${description}$ || ${n} =~ -${description}- || ${HCLOUD_FALLBACK_IMAGE-} == "${description}" ]]; then
        echo ${id}
        return 0
      fi
    done <<<${snapshots}

    while read -r description id; do
      if [[ -z ${description} ]]; then
        continue
      fi
      if [[ ${n} =~ -${description} ]]; then
        echo ${id}
        return 0
      fi
    done <<<${snapshots}
  done

  return 1
}
