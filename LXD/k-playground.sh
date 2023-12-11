#!/bin/bash
#
# Build / Show / Destroy a LXD Playground
#
# Version: 0.6.10
# Copyright (C) 2023 Calin Radoni
# License MIT (https://opensource.org/license/mit/)
#
# Note 1: this script is intended to do its job. It is not error-proof and could be improved with arguments and
# error checking but it may complicate usage, understanding and debugging !
#
# Note 2: for a short explanation see https://calinradoni.github.io/pages/230918-lxd-playground-for-k8s.html .
#
# Note 3: a playground created with this script can be used for tests with k0s and K3s.
# See https://calinradoni.github.io/pages/230926-lxd-k0s-k3s.html) for information.

# --- start of user configuration options

proj='kPlay'
net_prefix='10.70.10'

declare -i srv_cnt=1
declare -i wrk_cnt=0

# the user for SSH access and remote management
admin_user='calin'
# public key for SSH access and remote management
pub_key='ssh-ed25519 AAAA...'

# container name prefixes for servers and clients
srv_name='server'
wrk_name='worker'

# --- enf of user configuration options

declare user_cmd=''

declare -A ssh_cfg

declare net_name="${proj:0:15}"

# Print a message then exit the program
# Arguments:
#   - exit code (optional), defaults to 1. If the passed exit code is not numeric an error message is printed.
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

# Show the usage (help) for this script
show_usage() {
  cat << EOF
LXD playground script
Usage: ${0##*/} [-h] [<build | destroy>]
Options and commands:
    -h, --help  display this help message and exit
    build       create the playground
    destroy     destroy the playground
Without a command, the script will show the playground project.
EOF
}

create_the_project() {
  lxc project create "$proj" \
    -c features.images=false \
    -c features.profiles=true
}

create_the_network() {
  lxc network create "${net_name}" --type=bridge \
    ipv4.address="${net_prefix}.1/24" \
    ipv4.dhcp.ranges="${net_prefix}.64-${net_prefix}.127" \
    ipv4.nat=true \
    ipv6.address=none
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
    parent="${net_name}" \
    --project "$proj"

  # kmgs needed for Kubelet from k8s and derivatives
  lxc profile device add default kmsg unix-char \
    source="/dev/kmsg" path="/dev/kmsg" \
    --project "$proj"
}

# Set the common cloud-init configuration for all containers
set_common_config() {
  # the br_netfilter kernel module is required
  lxc profile set default --project "$proj" linux.kernel_modules=br_netfilter

  # these containers must be privileged
  lxc profile set default --project "$proj" security.privileged true

  # extended permission and /dev/kmsg are also required
cat << EOF | lxc profile set default --project "$proj" raw.lxc -
lxc.apparmor.profile = unconfined
lxc.cgroup.devices.allow = a
lxc.cap.drop =
lxc.mount.auto = cgroup:mixed proc:rw sys:mixed
lxc.mount.entry = /dev/kmsg dev/kmsg none defaults,bind,create=file
EOF

  # basic cloud-init config to set the admin user and SSH acces with public key
  cat << EOF | lxc profile set default --project "$proj" cloud-init.user-data -
#cloud-config
package_upgrade: true
packages:
  - openssh-server
ssh_pwauth: false
users:
- name: "${admin_user}"
  gecos: System administrator
  groups: adm,netdev,sudo
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  lock_passwd: true
  ssh_authorized_keys:
  - "${pub_key}"
EOF
}

# Create and launch a system container
# Create a `cloud-init.network-config` profile then launch a `ubuntu-minimal` image with that profile attached.
# Globals:
#   - proj is the project name
#   - net_prefix the 24 MSB of the IPv4, example: 192.168.5
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
  local caddr="${net_prefix}.$2"
  local ip_name="ip.$2"

  ssh_cfg["$1"]="$caddr"

  lxc profile create "${ip_name}" --project "$proj"

  cat << EOF | lxc profile set "${ip_name}" --project "$proj" cloud-init.network-config -
version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: static
        ipv4: true
        address: "$caddr"
        netmask: 255.255.255.0
        gateway: "${net_prefix}.1"
        control: auto
  - type: nameserver
    address: "${net_prefix}.1"
EOF

  lxc launch ubuntu-minimal:22.04 "$cname" \
    --project "$proj" \
    --profile default \
    --profile "${ip_name}"

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

# Remove old keys from `known_hosts` file
remove_old_host_keys() {
  printf '\nRemove the keys of previous hosts:\n\n'
  for key in "${!ssh_cfg[@]}"; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${ssh_cfg[$key]}"
  done
}

# Show proposed SSH config
show_SSH_config() {
  printf '\nYou may set your ~/.ssh/config file like:\n\n'

  for key in "${!ssh_cfg[@]}"; do
    printf 'Host %s\n' "$key"
    printf '    HostName "%s"\n' "${ssh_cfg[$key]}"
  done

  printf 'Host %s*\n' "${srv_name}"
  printf '    StrictHostKeyChecking no\n'
  printf 'Host %s*\n' "${wrk_name}"
  printf '    StrictHostKeyChecking no\n'
  printf '\n'
}

# Build the playground
# Globals:
#   - proj is the project name
#   - srv_name is the prefix for server names
#   - wrk_name is the prefix for worker names
# Arguments: none
build_playground() {
  if lxc project list -f csv | cut -d, -f1 | grep -q "$proj"; then
    exit_with_message 1 "Project $proj already exists !"
  fi

  if ! echo "${pub_key}" | ssh-keygen -l -f - >/dev/null 2>&1; then
    exit_with_message 2 "Provide a valid public key !"
  fi

  create_the_project
  create_the_network
  add_common_devices
  set_common_config

  for (( idx=0; idx<srv_cnt; idx++ ))
  do
    create_container "${srv_name}$idx" "$(( 10 + idx ))"
  done

  for (( idx=0; idx<wrk_cnt; idx++ ))
  do
    create_container "${wrk_name}$idx" "$(( 20 + idx ))"
  done

  remove_old_host_keys
  show_SSH_config

  printf 'Wait for cloud-init on all containers:\n'
  for (( idx=0; idx<srv_cnt; idx++ ))
  do
    wait_for_cloud_init "${srv_name}$idx"
  done
  for (( idx=0; idx<wrk_cnt; idx++ ))
  do
    wait_for_cloud_init "${wrk_name}$idx"
  done
}

# Show information about the playground
# Globals:
#   - proj is the project name
# Arguments: none
show_playground() {
  if ! lxc project list -f csv | cut -d, -f1 | grep -q "$proj"; then
    exit_with_message 1 "Project $proj not found !"
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
#   - net_name is the network name
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

  lxc network delete "${net_name}"
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
        user_cmd='build'
        ;;
      destroy)
        user_cmd='destroy'
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

parse_options "$@"

if ! command -v lxc >/dev/null 2>&1; then
  exit_with_message 1 'lxc command not found!'
fi

case "${user_cmd}" in
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
