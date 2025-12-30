# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: ./.wellknown entries will not cleaned here

function cleanLocalDataEntries() {
  local files

  echo -e " deleting local entries and facts ..."
  files=$(find ~/tmp/tor-relays/ -maxdepth 1 -type f)
  set +e
  while read -r name; do
    rm -f ./.ansible_facts/{,s1_}${name}
    sed -i \
      -e "/^${name}$/d" \
      -e "/^${name} /d" \
      -e "/ ${name}$/d" \
      -e "/ ${name} /d" \
      -e "/\[\"${name}:[0-9]*\"\]/d" \
      ${files} 2>/dev/null
    sed -i -e "/ # ${name}$/d" /tmp/tor-relays/*_bridgeline 2>/dev/null
  done < <(xargs -r -n 1 <<<$*)
  set -e
}

function cleanLocalDataFiles() {
  echo -e " deleting local data files ..."
  set +e
  while read -r name; do
    # certain files in {{ tmp_dir }} subdirs
    rm -f ~/tmp/tor-relays/{coredump,ddos,ddos6,dmesg,kconfig,trace}/${name}{,.*}
    rm -rf ~/tmp/tor-relays/tor-keys/${name}/
    # client certs
    rm -f ./secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  done < <(xargs -r -n 1 <<<$*)
  set -e
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

  if [[ ${LOOKUP_SNAPSHOT-} == "n" || -z ${snapshots} ]] || ! _setImageBySnapshot ${name}; then
    _setImageByHostname ${name}
  fi
}

function _setImageByHostname() {
  local name=${1?NAME NOT GIVEN}

  if [[ ${name} =~ "-un-" ]]; then
    echo 'ubuntu-24.04'
  elif [[ ${name} =~ "-dt-" ]]; then
    echo 'debian-13'
  elif [[ -n ${HCLOUD_FALLBACK_IMAGE-} ]]; then
    echo ${HCLOUD_FALLBACK_IMAGE}
  else
    xargs -n 1 <<<'debian-13 ubuntu-24.04' | shuf -n 1
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
