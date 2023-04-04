#!/usr/bin/env bash
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.  Please see LICENSE.txt at the top level of
# the source code distribution for details.
#
# @package install_laravel.sh
# @author <felix.bouynot@setenforce.one>
# @link https://gist.github.com/fbouynot/3a9cc8f1e5a9aea45b4446e5bf383843
# @copyright <felix.bouynot@setenforce.one>
#
# Install laravel on fedora with lemp
#

# When a command fails, bash exits instead of continuing with the rest of the script
set -o errexit
# This will make the script fail, when accessing an unset variable
set -o nounset
# This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails
set -o pipefail
# Enable debug mode by running your script as TRACE=1 ./script.sh instead of ./script.sh
if [[ "${TRACE-0}" == "1" ]]
then
    set -o xtrace
fi

readonly PROGNAME="${0##*/}"
readonly VERSION='1.0.0'

readonly DEFAULT_PROJECT=laravel
readonly DEFAULT_WEBSERVER=nginx
readonly DEFAULT_BACKEND=php-fpm

# Deal with argument pairs
while [[ $# -gt 1 ]]
do
    key="${1}"

    case "${key}" in
        -p|--project)
            export PROJECT="${2}"
            shift # consume -s
            ;;
        -w|--webserver)
            export PROJECT="${2}"
            shift # consume -s
            ;;
        -b|--backend)
            export PROJECT="${2}"
            shift # consume -s
            ;;
        *)
        ;;
    esac
    shift # consume $1
done

# Set defaults if no options specified
if [ -z "${PROJECT+x}" ]
then
    PROJECT="${DEFAULT_PROJECT}"
fi

# Set defaults if no options specified
if [ -z "${WEBSERVER+x}" ]
then
    WEBSERVER="${DEFAULT_WEBSERVER}"
fi

# Set defaults if no options specified
if [ -z "${BACKEND+x}" ]
then
    BACKEND="${DEFAULT_BACKEND}"
fi

help() {
    cat << EOF
Usage: ${PROGNAME} [ { -p | --project } <project-name> ] [ { -w | --webserver } <webserver-name> ] [ { -b | --backend } <backend-name> ]
-h    --help                                                     Print this message.
-v    --version                                                  Print the version.
-p    --project            STRING                                The project name.
-w    --webserver          STRING                                The chosen webserver.
-b    --backend            INT                                   The chosen backend server.
EOF

exit 2
}

version() {
    cat << EOF
${PROGNAME} version ${VERSION} under GPLv3 licence.
EOF

exit 2
}

# Display help message if -h --help -help h or help parameter
if [[ "${1-}" =~ ^-*h(elp)?$ ]]
then
    help
fi

# Display version message if -v --version -version v or version parameter
if [[ "${1-}" =~ ^-*v(ersion)?$ ]]
then
    version
fi

# Change directory to base script directory
cd "$(dirname "${0}")"

# Check root permissions
check_root() {
    # Check the command is run as root
    if [ "${EUID}" -ne 0 ]
    then
        printf 'E: please run as root\n' >&2
        exit 3
    fi

    return 0
}

# Install package from repository
install_package() {
    printf "%-50s" "${1} installation"
#    # Check if package is already installed
#    if dnf list installed -q "${1}" 1> /dev/null 2> /dev/null
#    then
#        printf " \\033[0;31mFAIL\\033[0m\\n"
#        printf 'E: %s is already installed.\n' "${1}" >&2
#        exit 4
#    fi

    # Install
    if ! dnf -yq --best install "${@}" 1> /dev/null 2> /dev/null
    then
        printf " \\033[0;31mFAIL\\033[0m\\n"
        printf 'E: %s installation failed\n' "${1}" >&2
        exit 5
    fi
    printf " \\033[0;32mOK\\033[0m\\n";

    return 0
}

# Enable and start package from repository
enable_package() {
    printf "%-50s" "${1} activation"
    # Start
    if ! systemctl enable --now "${1}" 1> /dev/null 2> /dev/null
    then
        printf " \\033[0;31mFAIL\\033[0m\\n"
        printf 'E: cannot start %s\n' "${1}" >&2
        exit 6
    fi
    printf " \\033[0;32mOK\\033[0m\\n";

    return 0
}

# Install nginx
install_nginx() {
    # Allow worker_processes mode auto
    setsebool -P httpd_setrlimit 1

    # Install
    install_package nginx nginx-core nginx-filesystem nginx-mimetypes
    # Start
    enable_package "nginx"

    return 0
}

# Install php-fpm
install_php-fpm() {
    # Allow execution of writable memory, needed for jit and opcache
    setsebool -P httpd_execmem 1
    # Allow the webserver to pass traffic to php-fpm
    # setsebool -P httpd_can_network_relay 1
    # enable if TCP socket only

    # Install
    install_package "php-fpm"

    # Add backend user if it does not exists
    id -u "${BACKEND}" 1> /dev/null 2> /dev/null || useradd "${BACKEND}" --system --no-create-home --user-group --shell /sbin/nologin
    # Configure php-fpm default pool user and group
    sed -i "s/user =.*/user = ${BACKEND}/g" /etc/php-fpm.d/www.conf
    sed -i "s/group =.*/group = ${BACKEND}/g" /etc/php-fpm.d/www.conf
#dedicated pool ?

    # Start
    enable_package "php-fpm"

    return 0
}

# Install mariadb
install_mariadb() {
    # Allow the backend to access mariadb
    # setsebool -P httpd_can_network_connect_db 1
    # enable if TCP socket only

    # Install
    install_package "mariadb-server"
    # Start
    enable_package "mariadb"

    mysql_secure_installation 1> /dev/null 2> /dev/null <<EOF

y
y
${1}
${1}
y
y
y
y
EOF

    return 0
}

# Main function
main() {
    local DB_PASSWORD
    set +o pipefail
    DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 128)
    set -o pipefail
    # Check root permissions
    check_root
    # Install and configure services
    install_nginx
    install_php-fpm
    install_mariadb "${DB_PASSWORD}"

    # Create project user
    mkdir -p /opt/"${PROJECT}"
    id -u "${PROJECT}" 1> /dev/null 2> /dev/null || useradd "${PROJECT}" -d /opt/"${PROJECT}" -M -r -s "$(which bash)"

    # Permissions step 1
    # Grants the project user and group read and write rights on project folder

    chown -R root:"${PROJECT}" /opt/"${PROJECT}"
    chmod 2770 /opt/"${PROJECT}"
    find /opt/"${PROJECT}" -type d -exec chmod 2770 {} \;
    find /opt/"${PROJECT}" -type f -exec chmod 0660 {} \;

    # Setup Framework
    # Need access to https://repo.packagist.org
    install_package "composer"
    su - "${PROJECT}" -c "composer global require laravel/installer 1> /dev/null 2> /dev/null"
    su - "${PROJECT}" -c "composer create-project laravel/laravel ${PROJECT} 1> /dev/null 2> /dev/null"
    su - "${PROJECT}" -c "cp /opt/${PROJECT}/${PROJECT}/.env.example /opt/${PROJECT}/${PROJECT}/.env 1> /dev/null 2> /dev/null"
# add to env ? what does it do ?
    sed -i 's/DB_USERNAME=.*/root/g' /opt/"${PROJECT}"/"${PROJECT}"/.env
    sed -i "s/DB_PASSWORD=.*/${DB_PASSWORD}/g" /opt/"${PROJECT}"/"${PROJECT}"/.env
    su - "${PROJECT}" -c "cd ${PROJECT} && php artisan storage:link 1> /dev/null 2> /dev/null"
# what does it do ?
# add bootstrap and auth ?

    # Permissions step 2
    # Grants the group 'devs' read, write, execute permissions on project folder
    # Grants the group 'webserver' read, permissions on public folder
    # Grants the group 'backend' read permissions on project folder, read and write permissions on storage folder

    groupadd devs
    setfacl -Rm d:g:devs:rwx /opt/"${PROJECT}"
    setfacl -m u:"${WEBSERVER}":--x,u:"${BACKEND}":--x,d:g:devs:rwx /opt/"${PROJECT}"
    setfacl -m u:"${WEBSERVER}":--x,u:"${BACKEND}":--x,d:g:devs:rwx /opt/"${PROJECT}"/"${PROJECT}"
    setfacl -Rm d:u:"${WEBSERVER}":r-x,d:u:"${BACKEND}":r-x,d:g:devs:rwx /opt/"${PROJECT}"/"${PROJECT}"/public /opt/"${PROJECT}"/"${PROJECT}"/resources /opt/"${PROJECT}"/"${PROJECT}"/vendor
    setfacl -Rm d:u:"${WEBSERVER}":r-x,d:u:"${BACKEND}":rwx,d:g:devs:rwx /opt/"${PROJECT}"/"${PROJECT}"/storage

    # Permissions step 3
    # Grants the webserver and backend processes permissions to read public folder, to read and write cache/storage folder
    # Grants logrotate process permissions to rotate the files in the log folder
    install_package "policycoreutils-python-utils"
    semanage fcontext -d "/opt/${PROJECT}/${PROJECT}/(public|resources|vendor)(/.*)?"
    semanage fcontext -a -t httpd_sys_content_t "/opt/${PROJECT}/${PROJECT}/(public|resources|vendor)(/.*)?"
    semanage fcontext -d "/opt/${PROJECT}/${PROJECT}/storage(/.*)?"
    semanage fcontext -a -t httpd_sys_rw_content_t "/opt/${PROJECT}/${PROJECT}/storage(/.*)?"
    semanage fcontext -d "/opt/${PROJECT}/${PROJECT}/storage/logs(/.*)?"
    semanage fcontext -a -t httpd_log_t "/opt/${PROJECT}/${PROJECT}/storage/logs(/.*)?"
    restorecon -RF /opt/"${PROJECT}"

    # Open ports
    firewall-cmd --zone public --add-service http --add-service https
    firewall-cmd --permanent --zone public --add-service http --add-service https

# add cleaning function
# group laravel specific
# prepare to deal with other servers
# nginx default blocks
# unix sockets
# verbose ?
# log file ?
# check distro ? (at least fedora vs centos)
# display ok / fail lnms like for permissions and firewall
# generate random password for mariadb
# add project user db

    systemctl restart nginx php-fpm mariadb

    exit 0
}

main "$@"
