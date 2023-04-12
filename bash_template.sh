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

# Define constants
readonly PROGNAME="${0##*/}"
readonly VERSION='1.0.0'
readonly DEFAULT_LOG_FILE=${PROGNAME}.log
readonly DEFAULT_VERBOSITY=0
readonly DEFAULT_QUIET=0

# Help function: print the help message
help() {
    cat << EOF
Usage: ${PROGNAME} [ { -l | --logfile } <logfile> ] [-Vhqv]
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

# Version function: print the version and license
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

# Function to log and run the command
log_and_run() {
    # Explicitly define our arguments
    local ARG_TEXT ARG_COMMAND EXIT_CODE OUTPUT

    ARG_TEXT=$1
    ARG_COMMAND=$2

    # Print nothing if quiet option
    if [[ "${QUIET}" == "0" ]]
    then
        printf "%-50s" "${ARG_TEXT}"
    fi
    echo "${ARG_TEXT}" >> "${LOG_FILE}"
    # Print and log stderr if verbose, log stderr if not
    if [[ "${VERBOSITY}" != "0" ]]
    then
        set +o pipefail
        eval "${ARG_COMMAND}" | tee -a "${LOG_FILE}"
        EXIT_CODE=${PIPESTATUS[0]}
        set -o pipefail
    else
        set +e
        eval "${ARG_COMMAND}" > /dev/null 2>> "${LOG_FILE}"
        EXIT_CODE=$?
        set -e
    fi
    echo "Returned: ${EXIT_CODE}" >> "${LOG_FILE}"

    # Print OK if the command ran successfully
    # Print FAIL otherwise (non-zero exit code)
    # Print nothing if option quiet set
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
    fi

    return "${EXIT_CODE}"
}

# Check root permissions
check_root() {
    # Check the command is run as root
    if [ "${EUID}" -ne 0 ]
    then
        printf 'E: please run as root\n' >&2
        return 3
    fi

    return 0
}

# Main function
main() {
    echo '' > "${LOG_FILE}" || (echo "E: Cannot write the log file: ${LOG_FILE}" >&2 && exit 4)
    log_and_run 'Checking permissions' 'check_root'
    log_and_run 'Print Hello World!' 'echo "Hello World!"'

    exit 0
}

main "$@"
