# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# note: ./.wellknown entries will not cleaned

function cleanLocalDataEntries() {
  local files

  echo -e " deleting local entries and facts ..."
  files=$(find ~/tmp/tor-relays/ -maxdepth 1 -type f)
  while read -r name; do
    rm -f ./.ansible_facts/{,s1_}${name}
    set +e
    sed -i \
      -e "/^${name}$/d" \
      -e "/^${name} /d" \
      -e "/ ${name}$/d" \
      -e "/ ${name} /d" \
      -e "/\[\"${name}:[0-9]*\"\]/d" \
      ${files} 2>/dev/null
    sed -i -e "/ # ${name}$/d" ~/tmp/tor-relays/*_bridgeline 2>/dev/null
    set -e
  done < <(xargs -r -n 1 <<<$*)
}

function cleanLocalDataFiles() {
  echo -e " deleting local data files ..."
  while read -r name; do
    rm -f ~/tmp/tor-relays/{coredump,ddos,ddos64,ddos80,ddos128,dmesg,kconfig,trace}/${name}{,.*}
    if [[ -z ${KEEP_TOR_KEYS-} ]]; then
      rm -rf ~/tmp/tor-relays/tor-keys/${name}/
    fi
    if [[ -z ${KEEP_CLIENT_CERTS-} ]]; then
      rm -f ./secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
    fi
  done < <(xargs -r -n 1 <<<$*)
}

# project is a global variable
function setProject() {
  project=$(hcloud context active)
  echo -e "\n >>> using Hetzner project \"${project?NO PROJECT FOUND}\""
}

# revert sort order helps later for the first match being the best match
function getSnapshots() {
  hcloud --quiet image list --type snapshot --output noheader --output columns=description,id,image_size |
    awk '{ if (NF == 4 && $3 != "-") { print $1, $2} }' |
    sort -r -n
}

function setImage() {
  local name=${1?NAME NOT GIVEN}

  if [[ -z ${snapshots} ]] || ! _setImageBySnapshot ${name}; then
    _setImageByHostname ${name}
  fi
}

# hcloud image list --type system --output json | jq -r '.[].name' | sort -uV
function _setImageByHostname() {
  local name=${1?NAME NOT GIVEN}

  if [[ ${name} =~ "-du-" ]]; then # bullseye
    echo debian-11
  elif [[ ${name} =~ "-db-" ]]; then # bookworm
    echo debian-12
  elif [[ ${name} =~ "-dt-" ]]; then # trixie
    echo debian-13
  elif [[ ${name} =~ "-uj-" ]]; then # jammy jellyfish
    echo ubuntu-22.04
  elif [[ ${name} =~ "-un-" ]]; then # noble numbat
    echo ubuntu-24.04
  elif [[ ${name} =~ "-ur-" ]]; then # resolute racoon
    echo ubuntu-26.04
  elif [[ -n ${HCLOUD_FALLBACK_IMAGE-} ]]; then
    echo ${HCLOUD_FALLBACK_IMAGE}
  else
    shuf -n 1 -e debian-{11,12,13} ubuntu-{22,24,26}.04
  fi
}

# examples for match ordering e.g. for hs0-dt-arm-stablerc-bp-cl-89
#   dt-arm-stablerc
#   dt-arm-stable
#   dt-arm
function _setImageBySnapshot() {
  local name=${1?NAME NOT GIVEN}

  local description id
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
