#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function info() {
  echo -e " $(date) $*                            "
}

function wait_for_jobs() {
  while fg 2>/dev/null; do
    :
  done
}

function pit_stop() {
  local sec=${1:-240}

  echo -en " $(date) sleeping ${sec}s\r"
  while ((sec--)); do
    if [[ -f /tmp/STOP ]]; then
      info "caught /tmp/STOP"
      wait_for_jobs
      info "exit\n"
      trap - INT QUIT TERM EXIT
      exit 0
    fi
    sleep 1
  done
}

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url tag
  case ${name} in
  # Tor project
  lyrebird)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git
    tag="main"
    ;;
  snowflake)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git
    tag="main"
    ;;
  tor)
    url=gitlab.torproject.org/tpo/core/tor.git
    tag="main"
    ;;
  # kernel
  ltsrc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    tag=linux-6.12.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    tag=master
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    tag=linux-6.18.y
    ;;
  *)
    echo " ${name} is not implemented"
    exit 2
    ;;
  esac

  git ls-remote --quiet https://${url} ${tag} |
    awk '{ print $1 }'
}

function git_changed() {
  local name=${1?NAME MUST BE GIVEN}

  # shellcheck disable=SC2155
  local old=$(cat /tmp/git.${name} 2>/dev/null)
  local new
  if new=$(git_ls_remote ${name}); then
    if [[ -n ${new} ]]; then
      echo ${new} >/tmp/git.${name}
      if [[ ${old} != "${new}" ]]; then
        return 0
      fi
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

trap 'touch /tmp/STOP' INT QUIT TERM EXIT

while :; do
  echo

  now=${EPOCHSECONDS}

  # app update
  for i in lyrebird snowflake tor; do
    if git_changed $i; then
      info "  app update: $i"
      limit=""
      case $i in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      ./site-setup.yaml --limit "${limit}" --tags $i &>${log}.$i.log || true
      pit_stop
    fi
  done

  # catch up image build jobs from previous round
  wait_for_jobs

  # kernel update
  for i in ltsrc mainline stablerc; do
    if git_changed $i; then
      info "  kernel update: $i"
      ./bin/test.sh -t image -b $i &>${log}.image.$i.log &
      ./site-setup.yaml --limit "h*-$i-*:!hix" --tags kernel-build -e kernel_git_build_wait=false &>${log}.$i.log || true
      pit_stop
    fi
  done

  info "check for down systems"
  sort -u ~/tmp/tor-relays/is_down >/tmp/is_down.before
  ./site-setup.yaml --limit 'hx:!hix' --tags poweron &>${log}.poweron.log || true
  sort -u ~/tmp/tor-relays/is_down >/tmp/is_down.after
  if [[ -s /tmp/is_down.before || -s /tmp/is_down.after ]]; then
    pit_stop

    # sshd may died
    poweroff=$(comm -12 /tmp/is_down.{before,after} | grep "^h" | xargs)
    if [[ -n ${poweroff} ]]; then
      info "  take down: $(wc -w <<<${poweroff})"
      xargs -r -n 1 -P 32 echo hcloud --quiet --poll-interval 10s server poweroff <<<${poweroff} &>${log}.poweroff.log || true
      pit_stop
    fi

    # trigger missed updates
    catch_up=$(grep -h "^h" /tmp/is_down.{before,after} | sort -u | xargs)
    if [[ -n ${catch_up} ]]; then
      info "  catch up: $(wc -w <<<${catch_up})"
      ./site-setup.yaml --limit "$(tr ' ' ',' <<<${catch_up})" --tags kernel-build,lyrebird,snowflake,tor -e kernel_git_build_wait=false &>${log}.catch_up.log || true
      pit_stop
    fi

    ./site-setup.yaml --limit "$(xargs </tmp/is_down.after | tr ' ' ',')" --tags poweron &>${log}.rebuild.log || true
    sort -u ~/tmp/tor-relays/is_down >/tmp/is_down.after_2
    rebuild=$(comm -12 /tmp/is_down.after{,_2} | grep "^h" | xargs)
    if [[ -n ${rebuild} ]]; then
      info "  rebuild: $(wc -w <<<${rebuild})"
      wait_for_jobs
      pit_stop
    fi
  fi

  sleep=$((EPOCHSECONDS - now))
  if [[ ${sleep} -lt 1800 ]]; then
    pit_stop ${sleep}
  fi
done
