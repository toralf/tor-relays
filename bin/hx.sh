#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url ver tok
  case ${name} in
  # Tor project
  #
  lyrebird)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git
    ver="main"
    ;;
  snowflake)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git
    ver="main"
    ;;
  tor)
    url=gitlab.torproject.org/tpo/core/tor.git
    ver="main"
    ;;
  # kernel
  #
  ltsrc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.12.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    ver=master
    # tok="GITLAB_API_TOKEN=abcd"
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.18.y
    ;;
  #
  #
  *)
    echo " ${name} is not implemented"
    exit 2
    ;;
  esac

  ${tok-} git ls-remote --quiet https://${url} ${ver} |
    awk '{ print $1 }'
}

function git_changed() {
  local name=${1?NAME MUST BE GIVEN}

  # shellcheck disable=SC2155
  local old=$(cat /tmp/git.${name} 2>/dev/null)
  # shellcheck disable=SC2155
  local new=$(git_ls_remote ${name} 2>/dev/null)
  if [[ -n ${new} ]]; then
    echo ${new} >/tmp/git.${name}
    if [[ -n ${old} && ${old} != "${new}" ]]; then
      info "git ${name}: $(cut -c -12 <<<${old}) -> $(cut -c -12 <<<${new})"
      return 0
    fi
  fi
  return 1
}

#######################################################################
set -euf
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

# ansible settings
export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="${HOME}"

cd $(dirname $0)/..
source ./bin/hx-lib.sh

if [[ ! -d ~/tmp/hx ]]; then
  mkdir ~/tmp/hx
fi
logprefix=~/tmp/hx/$(basename $0)
type hcloud >/dev/null
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0
while :; do
  # Tor app update
  for i in $(shuf -e lyrebird snowflake tor); do
    if git_changed ${i}; then
      info "app: ${i}"
      limit=""
      case ${i} in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      if ! ./site-setup.yaml --limit "${limit}" --tags ${i} &>${logprefix}.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  done

  # kernel update
  for i in $(shuf -e ltsrc mainline stablerc); do
    if git_changed ${i}; then
      info "kernel: ${i}"
      ./bin/hx-test.sh -t image_build -b ${i} &>${logprefix}.image_build.${i}.log &
      if ! ./site-setup.yaml --limit "hx,!hix,&h*-*-*-${i}*" --tags kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  done

  # handle unreachable systems
  info "check that all systems are up"
  if ! ./site-setup.yaml --limit 'hx,!hix' --tags poweron &>${logprefix}.down.log; then
    info "  NOT ok" >&2
  fi
  pit_stop 1
  down=$(xargs -r <~/tmp/tor_relays/is_down 2>/dev/null)
  if [[ -n ${down} ]]; then
    info "  power off/on: $(wc -w <<<${down})"
    info "    power off"
    if ! xargs -r -n 1 -P 32 hcloud --quiet --poll-interval 10s server poweroff <<<${down} \
      &>${logprefix}.poweroff.log; then
      info "  NOT ok" >&2
    fi
    info "    power on"
    if xargs -r -n 1 -P 32 hcloud --quiet --poll-interval 10s server poweron <<<${down} \
      &>${logprefix}.poweron.log; then
      info "  NOT ok" >&2
    fi
    pit_stop

    # catch up any missed updates
    info "  update: $(wc -w <<<${down})"
    if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${down})" --tags kernel-build,lyrebird,snowflake,tor \
      -e '{ "kernel_git_build_wait": false }' &>${logprefix}.update.log; then
      info "  NOT ok" >&2
    fi
    pit_stop

    # rebuild failed systems
    rebuild=$(xargs -r <~/tmp/hx/.retry)
    if [[ -n ${rebuild} ]]; then
      info "  rebuild: $(wc -w <<<${rebuild})"
      rebuild=$(shuf -n 64 -e ${rebuild} | xargs -r) # reduce blast radius
      if ! ./bin/rebuild-server.sh ${rebuild}; then
        info "  NOT ok" >&2
      fi
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${rebuild})" \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.rebuild.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  fi

  pit_stop
  wait_for_jobs
done
