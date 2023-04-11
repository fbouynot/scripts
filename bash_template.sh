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
readonly DEFAULT_LOG_FILE=${PROGNAME}.log
readonly DEFAULT_VERBOSITY=0
readonly DEFAULT_QUIET=0

help() {
    cat << EOF
Usage: ${PROGNAME} [ { -l | --logfile } <logfile> ] [-Vvh]
Install laravel and the web stack on GNU/linux.

Options:
    -h    --help                                                     Print this message and exit
    -l    --logfile          <string>                                The chosen logfile (default: ${DEFAULT_LOG_FILE})
    -q    --quiet                                                    No output at all
    -v    --verbose                                                  Print the verbose output
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
        -h|--help)
            help
            ;;
        -l|--logfile)
            export WORLD="${2}"
            shift # consume -l
            ;;
        -q|--quiet)
            export QUIET=1
            ;;
        -v|--verbose)
            export VERBOSITY=1
            ;;
        -vv)
            export VERBOSITY=2
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
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
VERBOSITY="${VERBOSITY:-$DEFAULT_VERBOSITY}"
QUIET="${QUIET:-$DEFAULT_QUIET}"

# Change directory to base script directory
cd "$(dirname "${0}")"

log_and_run() {
    # Explicitly define our arguments
    local ARG_TEXT ARG_COMMAND EXIT_CODE OUTPUT LOG_FILE

    ARG_TEXT=$1
    ARG_COMMAND=$2
    
    if [[ "${QUIET}" == "0" ]]
    then
        printf "%-50s" "${ARG_TEXT}"
    fi
    echo "${arg_text}" >> "${LOG_FILE}"
    if [[ "${VERBOSITY}" != "0" ]]
    then
        "${ARG_COMMAND}" | tee -a "${LOG_FILE}"
        EXIT_CODE=${PIPESTATUS[0]}
    else
        "${ARG_COMMAND}" 2>&1 > "${LOG_FILE}"
        EXIT_CODE=$?
    fi
    echo "Returned: ${EXIT_CODE}" >> "${LOG_FILE}"

    # print OK if the command ran successfully
    # or FAIL otherwise (non-zero exit code)
    if [[ "${EXIT_CODE}" == "0" ]]
    then
        if [[ "${QUIET}" == "0" ]]
        then
            printf " \\033[0;32mOK\\033[0m\\n"
        fi
    else
        if [[ "${QUIET}" == "0" ]]
        then
            printf " \\033[0;31mFAIL\\033[0m\\n"
        fi
        if [[ -n "${OUTPUT}" ]]
        then
            # print output in case of failure
            echo "${OUTPUT}"
        fi
    fi
    return "${EXIT_CODE}"
}

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
    log_and_run 'Checking permissions' 'check_root'
    log_and_run 'Print Hello World!' 'echo "Hello World!'"

    exit 0
}

main "$@"
