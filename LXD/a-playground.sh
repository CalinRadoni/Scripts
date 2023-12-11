#!/bin/bash
#
# Build / Show / Destroy a LXD Playground for Ansible
#
# Version: 0.11.0
# Copyright (C) 2023 Calin Radoni
# License MIT (https://opensource.org/license/mit/)
#
# When building, this script creates a project, a network bridge and the requested number of system containers.
# Each system container can be accessed with SSH using the configured credentials.
# The containers are assigned static IP addresses and those are added to dnsmasq.
# Using the default settings, the containers can be accessed by names: asc0.lxd, asc1.lxd and so on.
#
# Note: this script is intended to do its job. It is not error-proof and could be improved with arguments and
# error checking but it may complicate usage, understanding and debugging !
#
# Note: The resolved configuration persists as long as the bridge exists.
# You must repeat the commands 'sudo resolvectl dns ...' and 'sudo resolvectl domain ...'
# after each reboot and after LXD is restarted. To make it persistent and for mor information see:
# https://documentation.ubuntu.com/lxd/en/latest/howto/network_bridge_resolved/#how-to-integrate-with-systemd-resolved
#
# Using the default settings and having the private key in the `~/playgroundKey` file, access the containers with:
# ssh -i ~/playgroundKey calin@asc0.lxd
# or, if you changed your `~/.ssh/config`, simply use `ssh asc0`.

# --- start of user configuration options

proj='aPlay'
netPrefix='10.70.11'

declare -i vmCnt=2

# the user for SSH access and remote management
adminuser='calin'
# public key for SSH access and remote management. Here is an example to create a key pair:
# ssh-keygen -t ed25519 -f ~/playgroundKey -N "" -C ""
# pubkey='ssh-ed25519 AAAA...'
pubkey='ssh-ed25519 AAAA...'

# container name prefix for system containers
csName='asc'

dnsDomain='lxd'

# --- enf of user configuration options

declare usercmd=''

declare -A guestAddr

declare netName="${proj:0:15}"

# Print a message then exit the program
# Arguments:
#   - exit code (optional), defaults to 1. If the passed exit code is not numeric an error message is printed.
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
LXD playground script for Ansible
Usage: ${0##*/} [-h] [<build | destroy>]
Options and commands:
    -h, --help  display this help message and exit
    build       create the playground
    destroy     destroy the playground
Without a command, the script will show the playground project.
EOF
}

# create text formatting tokens
create_text_formatting() {
  normal_text=$(tput sgr0)
  readonly normal_text
  bold_text=$(tput bold)
  readonly bold_text
  dim_text=$(tput dim)
  readonly dim_text
  red_text=$(tput setaf 1)
  # shellcheck disable=SC2034
  readonly red_text
  green_text=$(tput setaf 2)
  readonly green_text
  blue_text=$(tput setaf 4)
  # shellcheck disable=SC2034
  readonly blue_text
}

create_the_project() {
  lxc project create "$proj" \
    -c features.images=false \
    -c features.profiles=true
}

create_the_network() {
  lxc network create "$netName" --type=bridge \
    ipv4.address="$netPrefix.1/24" \
    ipv4.dhcp.ranges="$netPrefix.64-$netPrefix.127" \
    ipv4.nat=true \
    ipv6.address=none \
    dns.domain="$dnsDomain"
    # dns.mode='managed'
}

add_common_devices() {
  # add root disk ...
  lxc profile device add default root disk \
    path=/ pool=default \
    --project "$proj"

  # ... and a network interface
  lxc profile device add default eth0 nic \
    name=eth0 \
    nictype=bridged \
    parent="$netName" \
    --project "$proj"
}

# Set the common cloud-init configuration for all containers
set_common_config() {
  # basic cloud-init config to set the admin user and SSH access with public key
  cat << EOF | lxc profile set default --project "$proj" cloud-init.user-data -
#cloud-config
package_upgrade: true
packages:
  - openssh-server
ssh_pwauth: false
users:
- name: "$adminuser"
  gecos: System administrator
  groups: adm,netdev,sudo
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  lock_passwd: true
  ssh_authorized_keys:
  - "$pubkey"
EOF
}

# Create and launch a system container
# Create a `cloud-init.network-config` profile then launch a `ubuntu-minimal` image with that profile attached.
# Globals:
#   - proj is the project name
#   - netPrefix the 24 MSB of the IPv4, example: 192.168.5
# Arguments:
#   - name of the container
#   - LSB of IPv4 address
# Example:
#   create_container server5 12
create_container() {
  [[ $# -eq 2 ]] || { printf 'This function needs two arguments !\n'; return 1; }

  [[ -n "$1" ]] || { printf 'First argument is null !\n'; return 2; }
  [[ "$2" =~ ^[0-9]+$ ]] || { printf 'Second argument must be a number !\n'; return 2; }
  (( "$2" > 1 && "$2" < 255 )) || { printf 'Second argument must be between 2 and 254, inclusive !\n'; return 2; }

  local cname="$1"
  local caddr="${netPrefix}.$2"
  local ipName="ip.$2"

  guestAddr["$1"]="$caddr"

  lxc profile create "$ipName" --project "$proj"

  cat << EOF | lxc profile set "$ipName" --project "$proj" cloud-init.network-config -
version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: static
        ipv4: true
        address: "$caddr"
        netmask: 255.255.255.0
        gateway: "${netPrefix}.1"
        control: auto
  - type: nameserver
    address: "${netPrefix}.1"
EOF

  lxc launch ubuntu-minimal:22.04 "$cname" \
    --project "$proj" \
    --profile default \
    --profile "$ipName"

  return 0
}

# Wait for cloud-init to finish
wait_for_cloud_init() {
  [[ $# -eq 1 ]] || { printf 'This function needs an argument !\n'; return 1; }
  [[ -n "$1" ]] || { printf 'The argument is null !\n'; return 2; }

  local cname="$1"
  lxc exec "$cname" --project "$proj" -- \
    cloud-init status --wait
}

# Add entries for static addresses
configure_dnsmasq() {
  printf '\nAdd DNS records.\n'
  local str=""
  for key in "${!guestAddr[@]}"; do
    str="${str}host-record=${key}.${dnsDomain},${guestAddr[$key]}\n"
  done

  echo -en "$str" | lxc network set "$netName" raw.dnsmasq -
}

# Remove old keys from `known_hosts` file
remove_old_host_keys() {
  printf '\nRemove the keys of previous hosts:\n\n'
  for key in "${!guestAddr[@]}"; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${guestAddr[$key]}"
  done
}

# Show proposed SSH config
show_SSH_config() {
  printf '\nYou may set your ~/.ssh/config file like:\n\n'

  for key in "${!guestAddr[@]}"; do
    printf 'Host %s\n' "$key"
    printf '    HostName "%s"\n' "${guestAddr[$key]}"
  done

  printf 'Host %s*\n' "$csName"
  printf '    StrictHostKeyChecking no\n'
  printf '    User %s\n' "$adminuser"
  printf '    IdentityFile _full_path_to_private_key_\n'
  printf '    IdentitiesOnly yes\n'
  printf '\n'
}

# Build the playground
# Globals:
#   - proj is the project name
#   - csName is the prefix for container's name
# Arguments: none
build_playground() {
  if lxc project list -f csv | cut -d, -f1 | grep -q "$proj"; then
    exit_with_message 1 "Project $proj already exists !"
  fi

  if ! echo "$pubkey" | ssh-keygen -l -f - >/dev/null 2>&1; then
    exit_with_message 2 "Provide a valid public key !"
  fi

  create_the_project
  create_the_network
  add_common_devices
  set_common_config

  for (( idx=0; idx<vmCnt; idx++ ))
  do
    create_container "$csName$idx" "$(( 10 + idx ))"
  done

  configure_dnsmasq

  remove_old_host_keys
  show_SSH_config

  printf 'Wait for cloud-init on all containers:\n'
  for (( idx=0; idx<vmCnt; idx++ ))
  do
    wait_for_cloud_init "$csName$idx"
  done

  printf '\nTo access the containers by name from host, %sexecute%s:\n%s' "${bold_text}" "${normal_text}" "${green_text}"
  printf 'sudo resolvectl dns %s %s\n' "${netName}" "${netPrefix}.1"
  printf 'sudo resolvectl domain %s '"'"'~%s'"'"'\n' "${netName}" "${dnsDomain}"
  printf '%sThe resolved configuration is NOT persistent. For more information see the heading of this script.\n%s\n' "${normal_text}${dim_text}" "${normal_text}"
}

# Show information about the playground
# Globals:
#   - proj is the project name
# Arguments: none
show_playground() {
  if ! lxc project list -f csv | cut -d, -f1 | grep -q "$proj"; then
  cat << EOF
Project $proj not found
Use '${0##*/} build' to create it
EOF
    exit_with_message 1
  fi

  printf 'Profiles in %s:\n' "$proj"
  lxc profile list --project "$proj"
  printf 'Containers in %s:\n' "$proj"
  lxc list --project "$proj"
  printf 'The networks:\n'
  lxc network list
}

# Destroy the playground
# Globals:
#   - proj is the project name
#   - netName is the network name
# Arguments: none
destroy_playground() {
  declare -a items
  declare -a profiles

  if ! lxc project list -f csv | cut -d, -f1 | grep -q "$proj"; then
    exit_with_message 0 "Project $proj not found."
  fi

  readarray -t items < <( lxc --project "$proj" list -f csv | cut -d, -f1 )
  readarray -t profiles < <( lxc --project "$proj" profile list -f csv | cut -d, -f1 )

  for elem in "${items[@]}"; do
    printf 'deleting %s\n' "$elem"
    lxc --project "$proj" delete "$elem" --force
  done

  for elem in "${profiles[@]}"; do
    if [[ "$elem" != 'default' ]]; then
      lxc --project "$proj" profile delete "$elem"
    fi
  done

  lxc project delete "$proj"

  lxc network delete "$netName"
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
      build)
        usercmd='build'
        ;;
      destroy)
        usercmd='destroy'
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
    show_usage
    exit_with_message 1
  fi
}

create_text_formatting

parse_options "$@"

if ! command -v lxc >/dev/null 2>&1; then
  exit_with_message 1 'lxc command not found!'
fi

case "$usercmd" in
  build)
    build_playground
    ;;
  destroy)
    destroy_playground
    ;;
  *)
    show_playground
    ;;
esac
