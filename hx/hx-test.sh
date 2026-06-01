#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: maintain golden image, test apps and kernels

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="/tmp"

cd $(dirname $0)/..

[[ $# -ge 2 ]]

arch='{arm,x86}'
os='{d13,u26}'
uid=$(printf "%07i" $$)
while getopts a:b:eo:t:u: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
  e) set +e ;; # created systems will be deleted eventually
  o) os=${OPTARG} ;;
  t) task=${OPTARG} ;;
  u) uid=${OPTARG} ;;
  *)
    echo "unknown opt ${opt}" >&2
    exit 1
    ;;
  esac
done

trap 'echo "  ^^    systems:    ${names}" >&2' INT QUIT TERM EXIT

if [[ ${task} =~ "dist" ]]; then
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-dist-x-x-${uid})
  time ./bin/create-server.sh ${names}
  if [[ ${task} == "dist_build" ]]; then
    go_ver_inventory=$(grep -Eo "'go[1-9]+\.[0-9]+\.[0-9]+'" inventory/systems-hetzner-test.yaml | tr -d "'")
    time ./site-test-setup.yaml --limit "h?-*-${uid}" -e '{ "go_version": "'${go_ver_inventory}'" }' \
       -e '{ "tor_build_from_source": true }'
  else
    time ./site-test-setup.yaml --limit "h?-*-${uid}" -e '{ "go_version": "" }'
  fi

elif [[ ${task} == "full" ]]; then
  branch=${branch:-'{dist,mainline,stablerc}'}
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "h?-*-${uid}" -e '{ "kernel_git_build_wait": false }'

elif [[ ${task} =~ "image" ]]; then
  branch=${branch:-'{mainline,stablerc}'}
  if [[ ${task} == "image_build" ]]; then
    # clone sources + build kernel
    names=$(
      eval echo hi-${os}-${arch}-${branch}-{bp,nobp,x}-{cl,nocl,x}-${uid} |
        xargs -n 1 |
        grep -v -e '^hi-d.*-.*-x' -e '^hi-u.*-.*-*bp' -e '^hi-u.*-.*-.*-*cl' |
        xargs
    )
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "h?-*-${uid}" --skip-tags "nginx-config,nginx-openssl"
  else
    # clone sources only
    names=$(eval echo hi-${os}-${arch}-${branch}-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "h?-*-${uid}" --skip-tags "nginx-config,nginx-openssl" \
      -e '{ "kernel_build": false }'
  fi

elif [[ ${task} =~ "kernel" ]]; then
  branch=${branch:-'{mainline,stablerc}'}
  names=$(
    eval echo hi-${os}-${arch}-${branch}-{bp,nobp,x}-{cl,nocl,x}-${uid} |
      xargs -n 1 |
      grep -v -e '^hi-d.*-.*-x' -e '^hi-u.*-.*-.*bp' -e '^hi-u.*-.*-.*-.*cl' |
      xargs
  )
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "h?-*-${uid}"

else
  echo "unknown task ${task}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
