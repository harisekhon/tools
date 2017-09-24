#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir2="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir2/..";

. ./tests/utils.sh

# because including bash-tools/util.sh resets the srcdir
srcdir="$srcdir2"

echo "
# ============================================================================ #
#                                   N g i n x
# ============================================================================ #
"

export NGINX_VERSIONS="${@:-${NGINX_VERSIONS:-latest 1.7 1.8 1.9 1.10 1.11 1.12 1.13}}"

NGINX_HOST="${DOCKER_HOST:-${NGINX_HOST:-${HOST:-localhost}}}"
NGINX_HOST="${NGINX_HOST##*/}"
NGINX_HOST="${NGINX_HOST%%:*}"
export NGINX_HOST

export NGINX_PORT_DEFAULT="80"

export DOCKER_IMAGE="nginx"
export DOCKER_CONTAINER="nagios-plugins-nginx-test"

startupwait 1
is_CI && let startupwait+=4

check_docker_available

trap_debug_env nginx

test_nginx(){
    local version="$1"
    echo "Setting up Nginx $version test container"
    #if ! is_docker_container_running "$DOCKER_CONTAINER"; then
        #docker rm -f "$DOCKER_CONTAINER" &>/dev/null || :
        #docker create --name "$DOCKER_CONTAINER" -p $NGINX_PORT:$NGINX_PORT "$DOCKER_IMAGE:$version"
        # docker-compose up to create docker_default network, otherwise just doing create and then start results in error:
        # ERROR: for nginx  Cannot start service nginx: network docker_default not found
        VERSION="$version" docker-compose up -d
        VERSION="$version" docker-compose stop
        docker cp "$srcdir/conf/nginx/conf.d/default.conf" docker_nginx_1:/etc/nginx/conf.d/default.conf
        #docker start "$DOCKER_CONTAINER"
        VERSION="$version" docker-compose start
        export NGINX_PORT="$(docker-compose port "$DOCKER_SERVICE" "$NGINX_PORT_DEFAULT" | sed 's/.*://')"
        when_ports_available $startupwait $NGINX_HOST $NGINX_PORT
    #else
    #    echo "Docker Nginx test container already running"
    #fi
    if [ -n "${NOTESTS:-}" ]; then
        return 0
    fi
    hr
    $perl -T ./watch_nginx_stats.pl --url "http://$NGINX_HOST:$NGINX_PORT/status" --interval=1 --count=3
    hr
    $perl -T ./watch_url.pl --url "http://$NGINX_HOST:$NGINX_PORT/" --interval=1 --count=3
    hr
    docker-compose down
    hr
    echo
}

run_test_versions "Nginx"
