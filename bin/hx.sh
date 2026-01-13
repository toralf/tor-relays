#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function info() {
  echo -e " $(date) $*                            "
}

function wait_for_jobs() {
  # shellcheck disable=SC2155
  local jobs=$(jobs -p | xargs -r)
  if [[ -n ${jobs} ]]; then
    info "jobs: ${jobs}"
    while fg 2>/dev/null; do
      :
    done
  fi
}

function pit_stop() {
  local sec=${1:-240}

  echo -en " $(date) sleeping ${sec}s    \r"
  while ((sec--)); do
    if [[ -f /tmp/STOP ]]; then
      trap - INT QUIT TERM EXIT
      info "caught /tmp/STOP"
      rm /tmp/STOP
      wait_for_jobs
      info "exit\n"
      exit 0
    fi
    if [[ -f /tmp/CONT ]]; then
      rm /tmp/CONT
      echo
      break
    fi
    sleep 1
  done
}

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url ver
  case ${name} in
  # Tor project
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
  ltsrc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.12.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    ver=master
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.18.y
    ;;
  *)
    echo " ${name} is not implemented"
    exit 2
    ;;
  esac

  git ls-remote --quiet https://${url} ${ver} |
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

cd $(dirname $0)/..

log=/tmp/$(basename $0)

trap 'echo stopping...; touch /tmp/STOP' INT QUIT TERM EXIT

while :; do
  start=${EPOCHSECONDS}

  # app update
  changed=0
  for i in lyrebird snowflake tor; do
    if git_changed $i; then
      changed=1
      info "app: $i"
      limit=""
      case $i in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      ./site-setup.yaml --limit "${limit}" --tags $i &>${log}.$i.log || true
    fi
  done
  [[ ${changed} -eq 1 ]] && pit_stop

  # kernel update
  changed=0
  for i in ltsrc mainline stablerc; do
    if git_changed $i; then
      info "kernel: $i"
      ./bin/hx-test.sh -t image_build -b $i &>${log}.image_build.$i.log &
      ./site-setup.yaml --limit "hx:!hi" --tags kernel-build -e kernel_git_build_wait=false &>${log}.$i.log || true
    fi
  done
  [[ ${changed} -eq 1 ]] && pit_stop

  if n=$(grep -c ^h ~/tmp/tor-relays/is_down); then
    info "down systems: $n"
    sort ~/tmp/tor-relays/is_down >/tmp/is_down.before
    ./site-setup.yaml --limit 'hx:!hi' --tags poweron &>${log}.poweron.log || true
    sort ~/tmp/tor-relays/is_down >/tmp/is_down.after
    pit_stop
    # sshd may died
    poweroff=$(comm -12 /tmp/is_down.{before,after} | grep "^h" | xargs -r)
    if [[ -n ${poweroff} ]]; then
      info "  power off/on: $(wc -w <<<${poweroff})"
      xargs -r -n 1 -P 32 echo hcloud --quiet --poll-interval 10s server poweroff <<<${poweroff} &>${log}.poweroff.log || true
      xargs -r -n 1 -P 32 echo hcloud --quiet --poll-interval 10s server poweron <<<${poweroff} &>${log}.poweron.log || true
      pit_stop
    fi

    # trigger missed updates
    update=$(grep -h "^h" /tmp/is_down.{before,after} | sort -u | xargs -r)
    if [[ -n ${update} ]]; then
      info "  update: $(wc -w <<<${update})"
      ./site-setup.yaml --limit "$(tr ' ' ',' <<<${update})" --tags kernel-build,lyrebird,snowflake,tor -e kernel_git_build_wait=false &>${log}.update.log || true
      pit_stop
    fi

    # rebuild systems still being down
    ./site-setup.yaml --limit "$(xargs -r </tmp/is_down.after | tr ' ' ',')" --tags poweron &>${log}.rebuild.log || true
    sort -u ~/tmp/tor-relays/is_down >/tmp/is_down.after_2
    rebuild=$(comm -12 /tmp/is_down.after{,_2} | grep "^h" | xargs -r)
    if [[ -n ${rebuild} ]]; then
      info "  rebuild: $(wc -w <<<${rebuild})"
      wait_for_jobs
      ./bin/rebuild-server.sh ${rebuild}
      ./site-setup.yaml --limit "$(tr ' ' ',' <<<${rebuild})" -e kernel_git_build_wait=false &>${log}.rebuild.log || true
      pit_stop
    fi
  fi

  wait_for_jobs

  pit_stop
  diff=$((EPOCHSECONDS - start))
  if [[ ${diff} -lt 1800 ]]; then
    pit_stop $((1800 - diff))
  fi
done
