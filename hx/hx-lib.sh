# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function pit_stop() {
  local rc=$?
  local stopfile=~/tmp/hx/${1-}
  local sec=${2:-60}

  info "sleep for ${sec}s"
  while ((sec--)) && [[ ! -f ${stopfile} && ! -f ${stopfile}-CONT ]]; do
    sleep 1
  done
  rm -f ${stopfile}-CONT

  if [[ -f ${stopfile} ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    echo
    info "caught ${stopfile}\n"
    rm ${stopfile}
    exit ${rc}
  fi
}
