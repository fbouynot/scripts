#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2154
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.  Please see LICENSE.txt at the top level of
# the source code distribution for details.
#
# @package install_laravel.sh
# @author <felix.bouynot@setenforce.one>
# @link https://github.com/fbouynot/scripts/blob/main/laravel_install.sh
# @copyright <felix.bouynot@setenforce.one>
#
# Install laravel on fedora with lemp
#
# TODO:
# Prepare to deal with other servers
# Verbose ?
# Log file ?
# Check distro ? (at least fedora vs centos)
# Display ok / fail lnms like for permissions / everything
# Dev vs prod, --no-dev app_url app_env
# Factorization

# -e: When a command fails, bash exits instead of continuing with the rest of the script
# -u: This will make the script fail, when accessing an unset variable
# -o pipefail: This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails
set -euo pipefail

# Replace the Internal Field Separator ' \n\t' by '\n\t' so you can loop through names with spaces 
IFS=$'\n\t'

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
readonly DEFAULT_DATABASE=mariadb
readonly DEFAULT_CACHE=redis
readonly DEFAULT_FQDN=localhost


help() {
    cat << EOF
Usage: ${PROGNAME} [ { -p | --project } <project-name> ] [ { -w | --webserver } <webserver-name> ] [ { -b | --backend } <backend-name> ] [ { -c | --cache } <cache-name> ] [-Vh]
Install laravel and the web stack on GNU/linux.

Options:
    -p    --project            <string>                              The project name (default: ${DEFAULT_PROJECT})
    -w    --webserver          <string>                              The chosen webserver (default: ${DEFAULT_WEBSERVER})
    -b    --backend            <string>                              The chosen backend server (default: ${DEFAULT_BACKEND})
    -d    --database           <string>                              The chosen database (default: ${DEFAULT_DATABASE})
    -c    --cache              <string>                              The chosen database (default: ${DEFAULT_CACHE})
    -f    --fqdn               <string>                              The chosen fqdn (default: ${DEFAULT_FQDN})
    -h    --help                                                     Print this message and exit
    -V    --version                                                  Print the version and exit
EOF

exit 2
}

version() {
    cat << EOF
${PROGNAME} version ${VERSION} under GPLv3 licence.
EOF

exit 2
}

# Deal with arguments
while [[ $# -gt 0 ]]
do
    key="${1}"

    case "${key}" in
        -p|--project)
            export project="${2}"
            shift # consume -p
            ;;
        -w|--webserver)
            export webserver="${2}"
            shift # consume -w
            ;;
        -b|--backend)
            export backend="${2}"
            shift # consume -b
            ;;
        -d|--database)
            export database="${2}"
            shift # consume -d
            ;;
        -c|--cache)
            export cache="${2}"
            shift # consume -c
            ;;
        -f|--fqdn)
            export fqdn="${2}"
            shift # consume -f
            ;;
        -h|--help)
            help
            ;;
        -V|--version)
            version
            ;;
        *)
        ;;
    esac
    shift # consume $1
done

# Set defaults if no options specified
project="${project:-$DEFAULT_PROJECT}"
webserver="${webserver:-$DEFAULT_WEBSERVER}"
backend="${backend:-$DEFAULT_BACKEND}"
database="${database:-$DEFAULT_DATABASE}"
cache="${cache:-$DEFAULT_CACHE}"
fqdn="${fqdn:-$DEFAULT_FQDN}"

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
    # Install
    dnf -yq remove  "${@}" 1> /dev/null 2> /dev/null
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
    if ! systemctl enable --now --quiet "${1}" 1> /dev/null 2> /dev/null
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
    local -r project="${1}"
    local -r fqdn="${2}"
    # Allow worker_processes mode auto
    setsebool -P httpd_setrlimit 1

    # Install
    install_package nginx nginx-core nginx-filesystem nginx-mimetypes
    # Configure
    cat > /etc/nginx/conf.d/"${project}".conf <<EOF
# PHP-FPM FastCGI server
# network or unix domain socket configuration

upstream ${project} {
        server unix:/run/php-fpm/${project}.sock;
}

server {
        listen 80;
        server_name ${fqdn};
#        return 301 https://\$host\$request_uri;
#}

#server {
#        listen 80 default_server;
#        server_name _;
#        return 444;
#}

#server {
#        listen          443 ssl http2 default_server;
#        listen          [::]:443 ssl http2 default_server;
#        server_name     _;

#        ssl_certificate "/etc/nginx/certificate.pem";
#        ssl_certificate_key "/etc/nginx/priv-key.pem";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers PROFILE=SYSTEM;
#        ssl_prefer_server_ciphers on;

#        return 444;
#}
#server {
#        listen       443 ssl http2;
#        listen       [::]:443 ssl http2;
        server_name  ${fqdn};
        root         /opt/${project}/${project}/public;

#        ssl_certificate "/etc/nginx/certificate.pem";
#        ssl_certificate_key "/etc/nginx/priv-key.pem";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers PROFILE=SYSTEM;
#        ssl_prefer_server_ciphers on;

# pass the PHP scripts to FastCGI server
#
# See conf.d/php-fpm.conf for socket configuration
#
index index.php index.html index.htm;

location ~ \.php$ {
    try_files \$uri =404;
    fastcgi_index  index.php;
    include        fastcgi_params;
    fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    fastcgi_pass   ${project};
}
        index           index.php;
        charset utf-8;
        gzip on;
        gzip_types text/css application/javascript text/javascript application/x-javascript image/svg+xml text/plain text/xsd text/xsl text/xml image/x-icon;

        location / {
            try_files   \$uri \$uri/ /index.php?\$query_string;
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
}
EOF
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
    install_package php-fpm php-opcache php-pdo php-mysqlnd php-pecl-redis

    # Add backend user if it does not exists
    id -u "${backend}" 1> /dev/null 2> /dev/null || useradd "${backend}" --system --no-create-home --user-group --shell /sbin/nologin
    # Configure php-fpm default pool user and group
    cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/"${project}".conf
#    echo ';nothing' > /etc/php-fpm.d/www.conf
#    sed -i "s/user =.*/user = ${backend}/g" /etc/php-fpm.d/"${project}".conf
#    sed -i "s/group =.*/group = ${backend}/g" /etc/php-fpm.d/"${project}".conf
#    sed -i "s/listen =.*/listen = listen = \/run\/php-fpm\/${backend}\.sock/g" /etc/php-fpm.d/"${project}".conf
#    sed -i "s/^\[www\]$/\[${backend}\]/g" /etc/php-fpm.d/"${project}".conf
    cat > /etc/php-fpm.d/"${project}".conf <<EOF
[${project}]
user = ${backend}
group = ${backend}
listen = /run/php-fpm/${project}.sock
listen.acl_users = ${webserver}
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
slowlog = /var/log/php-fpm/www-slow.log
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
EOF

    # Start
    enable_package "php-fpm"

    return 0
}

# Install mariadb
install_mariadb() {
    # Allow the backend to access mariadb if TCP socket
    # setsebool -P httpd_can_network_connect_db 1

    # Remove old database
    dnf remove -yq mariadb-server 1> /dev/null 2> /dev/null
    rm -rf /var/lib/mysql/* 1> /dev/null 2> /dev/null

    # Install
    install_package "mariadb-server"
    cat >> /etc/my.cnf.d/mariadb-server.cnf <<EOF
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/run/mariadb/mariadb.pid
EOF
    # Start
    enable_package "mariadb"

    mysql -sfu root <<EOF
-- set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${1}';
-- delete anonymous users
DELETE FROM mysql.user WHERE User='';
-- delete remote root capabilities
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- drop database 'test'
DROP DATABASE IF EXISTS test;
-- also make sure there are lingering permissions to it
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- make changes immediately
FLUSH PRIVILEGES;
EOF

    return 0
}

# Install redis
install_redis() {
    # Install
    install_package "redis"
    # Start
    enable_package "redis"

    return 0
}


# Main function
main() {
    local db_password db_project_password redis_password
    set +o pipefail
    db_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 128)
    db_project_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 128)
    redis_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 128)
    set -o pipefail
    # Check root permissions
    check_root
    # Install and configure services
    install_"${webserver}" "${project}" "${fqdn}"
    install_"${backend}"
    install_"${database}" "${db_password}"
    install_"${cache}"

    # Create project user
    rm -rf /opt/"${project}"
    mkdir -p /opt/"${project}"
    id -u "${project}" 1> /dev/null 2> /dev/null || useradd "${project}" -d /opt/"${project}" -M -r -s "$(which bash)"

    cat >> /etc/redis/redis.conf <<EOF
unixsocket /run/redis/redis.sock
unixsocketperm 770
requirepass ${redis_password}
EOF
    usermod -a -G redis "${backend}"
    usermod -a -G redis "${project}"
    systemctl restart "${cache}"
    mysql -sfu root -p"${db_password}" <<EOF
-- create project database
CREATE DATABASE ${project};
-- create project user
CREATE USER '${project}'@localhost IDENTIFIED BY '${db_project_password}';
-- grants permissions for project user on project database
GRANT ALL PRIVILEGES ON ${project}.* TO '${project}'@localhost;
-- make changes immediately
FLUSH PRIVILEGES;
EOF

    # Permissions step 1
    # Grants the project user and group read and write rights on project folder

    printf "%-50s" "permissions step 1: DAC classic"
    chown -R root:"${project}" /opt/"${project}"
    chmod 2770 /opt/"${project}"
    find /opt/"${project}" -type d -exec chmod 2770 {} \;
    find /opt/"${project}" -type f -exec chmod 0660 {} \;
    printf " \\033[0;32mOK\\033[0m\\n";
    # Setup Framework
    # Need access to https://repo.packagist.org
    install_package "composer"
    su - "${project}" -c "composer global require laravel/installer 1> /dev/null 2> /dev/null"
    rm -rf /opt/"${project}"/"${project}"
    su - "${project}" -c "composer create-project laravel/laravel ${project} 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cp /opt/${project}/${project}/.env.example /opt/${project}/${project}/.env 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan key:generate 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && composer require laravel/ui 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan ui bootstrap --auth 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && npm install 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && npm install @fontsource/nunito 1> /dev/null 2> /dev/null"
    sed -i '2s/.*/@import "@fontsource\/nunito";/g' /opt/"${project}"/"${project}"/resources/sass/app.scss
    sed -i '3s/.*/@import "@fontsource\/nunito\/500.css";/g' /opt/"${project}"/"${project}"/resources/sass/app.scss
    su - "${project}" -c "cd /opt/${project}/${project}/ && npm run build 1> /dev/null 2> /dev/null"
    sed -i '12d' /opt/"${project}"/"${project}"/resources/views/layouts/app.blade.php
    sed -i '12d' /opt/"${project}"/"${project}"/resources/views/layouts/app.blade.php
    sed -i '12d' /opt/"${project}"/"${project}"/resources/views/layouts/app.blade.php
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan config:cache 1> /dev/null 2> /dev/null"
# add to env ? what does it do ?
    sed -i 's/DB_HOST=.*/#DB_HOST=/g' /opt/"${project}"/"${project}"/.env
    sed -i 's/DB_PORT=.*/#DB_PORT=/g' /opt/"${project}"/"${project}"/.env
    echo 'DB_SOCKET=/var/lib/mysql/mysql.sock' >> /opt/"${project}"/"${project}"/.env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${project}/g" /opt/"${project}"/"${project}"/.env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${db_project_password}/g" /opt/"${project}"/"${project}"/.env
    sed -i "s/APP_URL=.*/APP_URL=${fqdn}/g" /opt/"${project}"/"${project}"/.env
    sed -i 's/CACHE_DRIVER=.*/CACHE_DRIVER=redis/g' /opt/"${PROJECT}"/"${PROJECT}"/.env
    sed -i 's/SESSION_DRIVER=.*/SESSION_DRIVER=redis/g' /opt/"${PROJECT}"/"${PROJECT}"/.env
    sed -i 's/REDIS_HOST=.*/REDIS_HOST=\/run\/redis\/redis.sock/g' /opt/"${PROJECT}"/"${PROJECT}"/.env
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${redis_password}/g" /opt/"${PROJECT}"/"${PROJECT}"/.env
    sed -i 's/REDIS_PORT=.*/REDIS_PORT=0/g' /opt/"${PROJECT}"/"${PROJECT}"/.env
cat<<EOF>>/opt/"${project}"/"${project}"/.env
SESSION_SECURE_COOKIE=true
SESSION_SAME_SITE_COOKIE=Strict
SESSION_DOMAIN=${fqdn}
EOF
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan config:clear 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan cache:clear 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd /opt/${project}/${project}/ && php artisan config:cache 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd ${project} && php artisan storage:link 1> /dev/null 2> /dev/null"
    su - "${project}" -c "cd ${project} && php artisan migrate 1> /dev/null 2> /dev/null"
# what does it do ?
# add bootstrap and auth ?

    # Permissions step 2
    # Grants the group 'devs' read, write, execute permissions on project folder
    # Grants the group 'webserver' read, permissions on public folder
    # Grants the group 'backend' read permissions on project folder, read and write permissions on storage folder

    printf "%-50s" "permissions step 2: DAC ACL"
    # Add group dev if it does not exists
    getent group devs 1> /dev/null 2> /dev/null || groupadd devs
    setfacl -Rm d:g:devs:rwx /opt/"${project}"
    setfacl -m u:"${webserver}":--x,u:"${backend}":--x,d:g:devs:rwx,g:"${project}":rwx,d:g:"${project}":rwx /opt/"${project}"
    setfacl -m u:"${webserver}":--x,u:"${backend}":--x,d:g:devs:rwx,g:"${project}":rwx,d:g:"${project}":rwx /opt/"${project}"/"${project}"
    setfacl -Rm u:"${backend}":r-x,d:u:"${backend}":--x,g:"${project}":rwx,d:g:"${project}":rwx /opt/"${project}"/"${project}"/app
    setfacl -Rm d:u:"${webserver}":r-x,d:u:"${backend}":r-x,d:g:devs:rwx,u:"${webserver}":r-x,u:"${backend}":r-x,g:devs:rwx,g:"${project}":rwx,d:g:"${project}":rwx /opt/"${project}"/"${project}"/public /opt/"${project}"/"${project}"/resources /opt/"${project}"/"${project}"/vendor
    setfacl -Rm d:u:"${webserver}":r-x,d:u:"${backend}":rwx,d:g:devs:rwx,u:"${webserver}":r-x,u:"${backend}":rwx,g:devs:rwx,g:"${project}":rwx,d:g:"${project}":rwx /opt/"${project}"/"${project}"/storage /opt/"${project}"/"${project}"/bootstrap/cache
    printf " \\033[0;32mOK\\033[0m\\n";

    # Permissions step 3
    # Grants the webserver and backend processes permissions to read public folder, to read and write cache/storage folder
    # Grants logrotate process permissions to rotate the files in the log folder

    install_package "policycoreutils-python-utils"
    printf "%-50s" "permissions step 3: MAC"
    set +e
    semanage fcontext -d "/opt/${project}/${project}/(public|resources|vendor)(/.*)?"
    semanage fcontext -d "/opt/${project}/${project}/storage(/.*)?"
    semanage fcontext -d "/opt/${project}/${project}/storage/logs(/.*)?"
    set -e
    semanage fcontext -a -t httpd_sys_content_t "/opt/${project}/${project}/(public|resources|vendor)(/.*)?"
    semanage fcontext -a -t httpd_sys_rw_content_t "/opt/${project}/${project}/storage(/.*)?"
    semanage fcontext -a -t httpd_log_t "/opt/${project}/${project}/storage/logs(/.*)?"
    restorecon -RF /opt/"${project}"
    printf " \\033[0;32mOK\\033[0m\\n";

    # Open ports
    printf "%-50s" "firewall rules"
    if ! firewall-cmd --zone public --add-service http --add-service https 1> /dev/null 2> /dev/null
    then
        printf " \\033[0;31mFAIL\\033[0m\\n"
        printf 'E: Cannot install firewall rules.\n' >&2
        exit
    fi
    if ! firewall-cmd --permanent --zone public --add-service http --add-service https 1> /dev/null 2> /dev/null
    then
        printf " \\033[0;31mFAIL\\033[0m\\n"
        printf 'E: Cannot enable firewall rules.\n' >&2
        exit
    fi
    printf " \\033[0;32mOK\\033[0m\\n";

    printf "%-50s" "restarting services"
    if ! systemctl restart "${webserver}" "${backend}" "${database}" 1> /dev/null 2> /dev/null
    then
        printf " \\033[0;31mFAIL\\033[0m\\n"
        printf 'E: Cannot restart services.\n' >&2
        exit
    fi
    printf " \\033[0;32mOK\\033[0m\\n";

    exit 0
}

main "$@"
