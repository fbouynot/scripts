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
VERSION='1.1.7'
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
NC="$(tput sgr0)" # No Color

DEFAULT_VERBOSITY=0
DEFAULT_MESSAGE="Hello, World!"
TMP_DIR="$(mktemp -d)" # Create temp folder

readonly PROGNAME VERSION RED GREEN NC DEFAULT_VERBOSITY DEFAULT_MESSAGE TMP_DIR

# Trap to delete temp folder file at script exit
trap 'rm -rf -- "$TMP_DIR"; printf "\n" >&4' EXIT

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
            verbosity=1
            ;;
        -vv)
            verbosity=2
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
# shellcheck disable=SC2317
check_root() {
    # Check the command is run as root
    if [ "${EUID}" -ne 0 ]
    then
        echo -e "${RED}E:${NC} please run as root" >&2
        return 1
    fi

    return 0
}

# Print message
# shellcheck disable=SC2317
print_message() {
    echo "${message}" > "${TMP_DIR}/output" || return 1
    cat "${TMP_DIR}/output" || return 1

    return 0
}

# Call the functions and print pretty output
# arg1: message
# arg2: command
step() {
    printf "%-50s" "${1}" 1>&4 2>&5
    "${2}" || (printf "%s\n" "${RED}FAIL${NC}" >&5 && exit 4)
    printf "%s\n" "${GREEN}OK${NC}" 1>&4 2>&5

    return 0
}

# Main function
main() {
    # Set verbosity
    # Save address of stdout to 4
    exec 4>&1
    # Save address of stderr to 5
    exec 5>&2
    case "${verbosity}" in
        1|--destination)
            # Remove messages that would be sent to stdout, keep stderr one
            exec 1>/dev/null
            ;;
        2|--folder)
            # Print both stdout and stderr messages
            ;;
        *)
            # Remove both stdout and stderr messages
            exec 1> /dev/null 2>/dev/null
            ;;
    esac
    
    # Check for root permissions
    step "Check permissions" "check_root"

    # Print Hello World! on stdout
    step "Print message" "print_message"

    exit 0
}

main "$@"
