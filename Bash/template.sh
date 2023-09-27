#!/bin/bash
#
# Template script that handle options and arguments
#
# Version: 1.0.1
# Copyright (C) 2023 Calin Radoni
# License MIT (https://opensource.org/license/mit/)
#
# There is a post related to this script at:
# https://calinradoni.github.io/pages/230123-bash-scripting.html

# Initialize all option and argument variables, this operation
# prevents a possible contamination from the environment.
# These variables are set by the 'parse_options' function.
declare -a ARGS=()
declare -i verbose=0
declare infile=''

# Print a message then exit the program
# Arguments:
#   - exit code (optional), defaults to 1.
#     If the passed exit code is not numeric an error message is printed.
#   - message (optional), requires exit code to be provided.
exit_with_message() {
    declare exit_code="${1:-1}"
    if [[ -n "$2" ]]; then
        printf -- '%s\n' "$2" >&2
    fi
    if [[ "$exit_code" != +([[:digit:]]) ]]; then
        printf 'Incorrect exit code!\n' >&2
        exit 1
    fi
    exit "$exit_code"
}

# Show the usage (help) for this script
show_usage() {
    cat << EOF
Usage: ${0##*/} [-h] [-v] [-f INFILE] [ARGs] ...
Description of what this script does
Options:
    -h, --help         display this help message and exit
    -v, --verbose      verbose mode. Use multipletimes for increased verbosity
    -f, --file INFILE  select INFILE as the input file
EOF
}

# Parse options and their arguments
# Globals:
#   ARGS will hold the arguments
# Arguments:
#   the options to be parsed
# Example:
#   parse_options "$@"
parse_options() {
    while :; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                ((verbose++));;
            -f|--file)
                if [[ -z "$2" ]]; then
                    exit_with_message 1 "[$1] needs an argument!"
                    exit 1
                fi
                if [[ "$2" == '--' ]]; then
                    exit_with_message 1 "[$1] needs an argument!"
                    exit 1
                fi
                infile="$2"
                shift
                ;;
            --) # explicit end of all options, break out of the loop
                shift
                break
                ;;
            -?*)
                exit_with_message 1 "[$1] is an invalid option!"
                exit 1
                ;;
            *)  # this is the default processing case
                # there are no more options, break out of the loop
                break
        esac
        shift
    done

    if (($# > 0)); then
        ARGS=("$@")
    else
        ARGS=()
    fi
}

parse_options "$@"

# demo usage code start

if ((verbose > 0)); then
    printf 'Verbosity level is set to %d\n' "$verbose"
fi

if [[ -n "$infile" ]]; then
    printf 'The input file is %s\n' "$infile"

    # test if the file is readable (use -w to test if the file is writable)
    if [[ ! -r "$infile" ]]; then
        printf -- '%s is not readable !\n' "$infile" >&2
    fi
fi

if ((${#ARGS[@]} > 0)); then
    printf 'The are %d remaining arguments:\n' "${#ARGS[@]}"
    printf -- '%s\n' "${ARGS[*]}"
fi
for arg in "${ARGS[@]}"; do
    printf '<%s>\n' "$arg"
done
for ((i=0; i<"${#ARGS[@]}"; i++)); do
    printf '%d: <%s>\n' "$i" "${ARGS[$i]}"
done

# demo usage code end

exit 0
