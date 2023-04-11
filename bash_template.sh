#!/usr/bin/env bash
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.  Please see LICENSE.txt at the top level of
# the source code distribution for details.
#
# @package bash_template.sh
# @author <felix.bouynot@setenforce.one>
# @link https://github.com/fbouynot/scripts/blob/main/bash_template.sh
# @copyright <felix.bouynot@setenforce.one>
#
# Print Hello world!
#

# -e: When a command fails, bash exits instead of continuing with the rest of the script
# -u: This will make the script fail, when accessing an unset variable
# -o pipefail: This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails
set -euo pipefail
# Enable debug mode by running your script as TRACE=1 ./script.sh instead of ./script.sh
if [[ "${TRACE-0}" == "1" ]]
then
    set -o xtrace
fi

readonly PROGNAME="${0##*/}"
readonly VERSION='1.0.0'

readonly DEFAULT_WORLD=Earth

help() {
    cat << EOF
Usage: ${PROGNAME} [ { -w | --world } <world-name> ] [-Vh]
Install laravel and the web stack on GNU/linux.

Options:
    -w    --webserver          <string>                              The chosen webserver (default: ${DEFAULT_WORLD})
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
        -w|--world)
            export WORLD="${2}"
            shift # consume -w
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
WORLD="${WORLD:-$DEFAULT_WORLD}"

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

# Main function
main() {
    check_root
    local HELLO
    HELLO='Hello'
    echo "${HELLO} ${WORLD}!"

    exit 0
}

main "$@"
