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
    # in wellknown files there're 2 subsequent lines to be deleted
    sed -i -e "/^# ${name}$/{N;d;}" ~/tmp/tor-relays/{{,hashed-bridge-}rsa-fingerprint,ed25519-master-pubkey}.txt
    # 1-line pattern
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
      rm -rf ~/tmp/tor-relays/tor-identity/${name}/
    fi
    if [[ -z ${KEEP_CLIENT_CERTS-} ]]; then
      rm -f ./secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
    fi
  done < <(xargs -r -n 1 <<<$*)
}

function setProject() {
  # project is a global variable
  project=$(hcloud context active)
  echo -e "\n >>> using Hetzner project \"${project?NO PROJECT FOUND}\""
}

# revert sort order ensures that in _getImageBySnapshot() the first match is the best one
function getSnapshots() {
  hcloud --quiet image list --type snapshot --output noheader --output columns=description,id,image_size |
    awk '{ if (NF == 4 && $3 != "-") { print $1, $2 } }' |
    sort -r -n
}

function getImage() {
  local name

  if [[ -n ${HCLOUD_IMAGE-} ]]; then
    echo ${HCLOUD_IMAGE}
  else
    name=${1:?NAME NOT GIVEN}
    if [[ -z ${snapshots} ]] || ! _getImageBySnapshot ${name}; then
      _getImageByHostname ${name}
    fi
  fi
}

# hcloud --quiet image list --type system --output json | jq -r '.[].name' | sort -uV
function _getImageByHostname() {
  local name os

  name=${1:?NAME NOT GIVEN}
  os=$(cut -f 2 -d '-' -s <<<${name}) # e.g. 'd13' or 'u26'
  case ${os} in
  d*) sed -e 's,d,debian-,' <<<${os} ;;
  u*) sed -e 's,u,ubuntu-,' -e 's,$,.04,' <<<${os} ;;
  *)
    if [[ -n ${HCLOUD_FALLBACK_IMAGE-} ]]; then
      echo ${HCLOUD_FALLBACK_IMAGE}
    else
      # 12,13: bookworm, trixie
      # 24,26: noble, resolute
      shuf -n 1 -e debian-{12,13} ubuntu-{24,26}.04
    fi
    ;;
  esac
}

# example for match ordering:
#   hostname: hs0-d13-arm-stablerc-bp-cl-89
#   descriptions:
#     d13-arm-stablerc
#     d13-arm-stable
#     d13-arm
function _getImageBySnapshot() {
  local name description id alt_name

  name=${1:?NAME NOT GIVEN}

  if [[ -z ${snapshots} ]]; then
    return 1
  fi

  # word match
  while read -r description id; do
    if [[ ${name} =~ -${description}-*$ ]]; then
      echo ${id}
      return 0
    fi
  done <<<${snapshots}

  # starts with
  while read -r description id; do
    if [[ ${name} =~ -${description} ]]; then
      echo ${id}
      return 0
    fi
  done <<<${snapshots}

  # use "mainline" as fallback to avoid the (expensive) clone of a kernel git repository
  if [[ ! ${name} =~ "-dist" && ! ${name} =~ "-mainline" ]]; then
    if alt_name=$(awk -F- -v OFS=- '{ if (NF >=4) { $4="mainline"; print } }' <<<${name}); then
      if [[ -n ${alt_name} ]] && _getImageBySnapshot ${alt_name}; then
        return 0
      fi
    fi
  fi

  return 1
}
