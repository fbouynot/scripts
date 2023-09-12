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

# Replace the Internal Field Separator ' \n\t' by '\n\t' so you can loop through names with spaces 
IFS=$'\n\t'

# Enable debug mode by running your script as TRACE=1 ./script.sh instead of ./script.sh
if [[ "${TRACE-0}" == "1" ]]
then
    set -o xtrace
fi

# Define constants
PROGNAME="${0##*/}"
VERSION='1.1.5'
RED="$(tput setaf 1)"
NC="$(tput sgr0)" # No Color

DEFAULT_VERBOSITY=0
DEFAULT_MESSAGE="Hello, World!"

readonly PROGNAME VERSION RED NC DEFAULT_VERBOSITY DEFAULT_MESSAGE

# Help function: print the help message
help() {
    cat << EOF
Usage: ${PROGNAME} [-Vhmv]
Print "Hello, World!"

Options:
    -h    --help                                                     Print this message and exit
    -m    --message                                                  Message to print (default: ${DEFAULT_MESSAGE})
    -v    --verbose                                                  Print the verbose output
    -V    --version                                                  Print the version and exit
EOF

exit 2
}

# Version function: print the version and license
version() {
    cat << EOF
${PROGNAME} version ${VERSION} under GPLv3 licence.
EOF

exit 2
}

# Display help message if there is no parameter
# if [[ $# -eq 0 ]]
# then
#     help
# fi

# Deal with arguments
while [[ $# -gt 0 ]]
do
    key="${1}"

    case "${key}" in
        -h|--help)
            help
            ;;
        -m|--message)
            message="${2}"
            shift # consume -m
            ;;
        -v|--verbose)
            export verbosity=1
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
verbosity="${verbosity:-$DEFAULT_VERBOSITY}"
message="${message:-$DEFAULT_MESSAGE}"

# Change directory to base script directory
cd "$(dirname "${0}")"

# Check root permissions
check_root() {
    # Check the command is run as root
    if [ "${EUID}" -ne 0 ]
    then
        echo -e "${RED}E:${NC} please run as root" >&2
        exit 3
    fi

    return 0
}

# Main function
main() {
    # Check for root permissions
    check_root

    # Print Hello World! on stdout
    echo "${message}"

    # Compress program with xz
    case "${verbosity}" in
        1)
            tar cvvJf archive.xz "${PROGNAME}"
            ;;
        *)
            tar cJf archive.xz "${PROGNAME}" > /dev/null 2>&1
            ;;
    esac

    exit 0
}

main "$@"
