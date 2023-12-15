#!/bin/bash
#
# This script makes a simple generalization of a Linux system.
# It is meant to be used on virtual machines before creating a template out of them.
#
# Version: 0.2.3
# Copyright (C) 2023 Calin Radoni
# License MIT (https://opensource.org/license/mit/)

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
  if [[ "${exit_code}" != +([[:digit:]]) ]]; then
    printf 'Incorrect exit code!\n' >&2
    exit 1
  fi
  exit "${exit_code}"
}

is_vm_or_container() {
  if ! command -v hostnamectl >/dev/null 2>&1; then
    exit_with_message 1 'lxc command not found!'
  fi

  local chassis=''
  chassis=$(hostnamectl chassis)
  if [[ "${chassis}" != 'vm' && "${chassis}" != 'container' ]]; then
    exit_with_message 2 'No virtual environment detected!'
  fi
}

if [[ "$EUID" != 0 ]]; then
  exit_with_message 1 'This script must be run as root!'
fi

is_vm_or_container

# empty machine-id
true > /etc/machine-id

# delete host keys
rm -f /etc/ssh/ssh_host_*
printf '\nTo generate a new set of host keys use:\n'
printf 'ssh-keygen -v -A\n'
printf 'on the new host\n\n'

# empty log files
journalctl --rotate --vacuum-time=1s

# remove unneeded packages
apt-get -y autoremove

# clean the local apt repository
apt-get -y clean
