#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url ver tok
  case ${name} in
  # apps
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
    ver=linux-6.18.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    ver=master
    # tok="GITLAB_API_TOKEN=abcd"
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-7.0.y
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

# an empty "old" is not considered as "changed"
function git_changed() {
  local group=${1?GROUP MUST BE GIVEN}
  local name=${2?NAME MUST BE GIVEN}

  # shellcheck disable=SC2155
  local old=$(cat ~/tmp/hx/git.${group}.${name} 2>/dev/null)
  # shellcheck disable=SC2155
  local new=$(git_ls_remote ${name} 2>/dev/null)
  if [[ -n ${new} ]]; then
    echo ${new} >~/tmp/hx/git.${group}.${name}
    if [[ -n ${old} && ${old} != "${new}" ]]; then
      info "git ${group} ${name}: $(cut -c -12 <<<${old}) -> $(cut -c -12 <<<${new})"
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
source ./hx/hx-lib.sh

if [[ ! -d ~/tmp/hx ]]; then
  mkdir ~/tmp/hx
fi
logprefix=~/tmp/hx/$(basename $0)
type hcloud >/dev/null
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0

while :; do
  find ~/tmp/hx -maxdepth 1 -type f \( -name "job.*.create" -o -name "job.*.delete" -o -name "job.*.rebuild" \) |
    sort -V |
    while read -r job; do
      action=$(cut -f 3 -d '.' <<<${job})
      names=$(xargs <${job})
      if ! ./bin/${action}-server.sh ${names} &>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
      if [[ ${action} != "delete" ]]; then
        if ! ./site-setup.yaml --limit "tr ' ' ',' <<<${names}" &>${logprefix}.job.setup.log; then
          info "  NOT ok" >&2
        fi
      fi
      pit_stop
    done

  # Tor app update(s)
  for i in $(shuf -e lyrebird snowflake tor); do
    if git_changed app ${i}; then
      info "update app: ${i}"
      limit=""
      case ${i} in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      if ! ./site-setup.yaml --limit "${limit}" --tags ${i} &>${logprefix}.app.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  done

  # kernel update(s)
  for i in $(shuf -e ltsrc mainline stablerc); do
    if git_changed kernel ${i}; then
      info "update kernel: ${i}"
      if ! ./site-setup.yaml --limit "hx,!hix,&h*-*-*-${i}*" --tags kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.kernel.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  done

  # unreachable systems
  info "check for down systems"
  if ! ./site-setup.yaml --limit 'hx,!hix' --tags poweron &>${logprefix}.down.log; then
    info "  NOT ok" >&2
  fi
  pit_stop 1
  down=$(grep "^h" ~/tmp/tor_relays/is_down 2>/dev/null | xargs)
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

    # catch up missed update(s) if any
    info "  update: $(wc -w <<<${down})"
    if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${down})" --tags kernel-build,lyrebird,snowflake,tor \
      -e '{ "kernel_git_build_wait": false }' &>${logprefix}.update.log; then
      info "  NOT ok" >&2
    fi
    pit_stop

    # rebuild failed system(s)
    rebuild=$(xargs <~/tmp/hx/.retry)
    if [[ -n ${rebuild} ]]; then
      info "  rebuild: $(wc -w <<<${rebuild})"
      rebuild=$(shuf -n 64 -e ${rebuild} | xargs) # limit blast radius
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

  pit_stop 300
done
