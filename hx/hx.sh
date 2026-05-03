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

export ANSIBLE_RETRY_FILES_ENABLED="True"
export ANSIBLE_RETRY_FILES_SAVE_PATH="${HOME}/tmp/hx"

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
  # jobs
  while read -r job; do
    info "work on job $(basename ${job})"

    if [[ ! -s ${job} ]]; then
      info "  empty" >&2
      rm ${job}
      continue
    fi
    action=$(cut -f 3 -d '.' <<<${job})
    names=$(xargs <${job})
    mv ${job} /tmp/

    if [[ ${action} != "setup" ]]; then
      if ! ./bin/${action}-server.sh ${names} &>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
    fi
    if [[ ${action} != "delete" ]]; then
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" &>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
    fi
    pit_stop
  done < <(
    find ~/tmp/hx -maxdepth 1 -type f \( -name "job.*.create" -o -name "job.*.delete" -o -name "job.*.rebuild" -o -name "job.*.setup" \) |
      sort -V
  )

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
      if ! ./site-setup.yaml --limit 'hx,!hix,&h*-*-*-'${i}'*' --tags kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.kernel.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop
    fi
  done

  # down systems
  rm -f ~/tmp/hx/site-{info,setup}.retry ~/tmp/hx/down-{after,before}
  info "uptime"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags uptime &>${logprefix}.uptime.log; then
    info "  NOT ok" >&2
  fi
  grep "^h" ~/tmp/hx/site-info.retry 2>/dev/null |
    grep -v "^hi" |
    sort |
    xargs -r >~/tmp/hx/down-before

  if [[ -s ~/tmp/hx/down-before ]]; then
    info "  down before: $(wc -w <~/tmp/hx/down-before)"
    pit_stop
    info "  poweron"
    if ! ./site-setup.yaml --limit "$(xargs <~/tmp/hx/down-before | tr ' ' ',')" \
      --tags poweron &>${logprefix}.poweron.log; then
      info "  NOT ok" >&2
    fi

    grep "^h" ~/tmp/hx/site-setup.retry 2>/dev/null |
      grep -v "^hi" |
      sort |
      xargs -r >~/tmp/hx/down-after
    info "  down after: $(wc -w <~/tmp/hx/down-after)"

    # only down before; catch up any missed updates
    number=${EPOCHSECONDS}
    comm -2 ~/tmp/hx/down-before ~/tmp/hx/down-after |
      shuf -n 64 |
      sort |
      xargs -r >~/tmp/hx/job.${number}.setup
    info "  job setup: $(wc -w <~/tmp/hx/job.${number}.setup)"

    # down before and after: rebuild to keep same ip
    number=${EPOCHSECONDS}
    comm -12 ~/tmp/hx/down-before ~/tmp/hx/down-after |
      shuf -n 64 |
      sort |
      xargs -r >~/tmp/hx/job.${number}.rebuild
    info "  job rebuild: $(wc -w <~/tmp/hx/job.${number}.rebuild)"

    # only down after: check again next round
  fi

  # main loop
  pit_stop 300
done
