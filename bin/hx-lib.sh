# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function wait_for_jobs() {
  # shellcheck disable=SC2155
  local jobs=$(jobs -p | xargs -r)

  if [[ -n ${jobs} ]]; then
    info "wait for jobs: ${jobs}"
    while fg 2>/dev/null; do
      :
    done
  fi
}

function pit_stop() {
  local rc=$?
  local sec=${1:-60}

  echo -en " $(date) sleeping up to ${sec}s    \r"
  while ((sec--)) && [[ ! -f ~/tmp/hx/STOP ]]; do
    sleep 1
  done
  if [[ -f ~/tmp/hx/STOP ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    info "caught STOP"
    wait_for_jobs
    info "exit\n"
    exit ${rc}
  fi
}
