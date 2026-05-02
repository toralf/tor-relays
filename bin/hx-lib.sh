# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function wait_for_bg_jobs() {
  local n

  n=$(jobs -r | wc -l)
  if [[ ${n} -gt 0 ]]; then
    info "wait for ${n} background job(s) ..."
    wait
  fi
}

function pit_stop() {
  local rc=$?
  local sec=${1:-60}
  local stopfile=${2:-~/tmp/hx/STOP}

  echo -en " $(date) sleep for ${sec}s    \r"
  while ((sec--)) && [[ ! -f ${stopfile} ]]; do
    sleep 1
  done
  if [[ -f ${stopfile} ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    info "caught STOP"
    wait_for_bg_jobs
    info "exit\n"
    exit ${rc}
  fi
}
