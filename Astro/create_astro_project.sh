#!/bin/bash
#
# Initialize an Astro project using Podman or Docker
#
# Version: 1.5.2
# Copyright (C) 2024 Calin Radoni
# License MIT (https://opensource.org/license/mit/)
# https://github.com/CalinRadoni/Scripts
#
# Pass the name of destination directory as argument

notesDir='notes'
scriptDir='scripts'

declare -a remoteScriptNames
remoteScriptNames=('build.sh' 'preview_build.sh' 'run_dev.sh' 'update_node_astro_packages.sh')
remoteRawRepo='https://github.com/CalinRadoni/Scripts/raw/main/Astro/'

declare -a gitIgnoreEntries
gitIgnoreEntries=('.vscode/')

create_the_project() {
  if command -v podman >/dev/null 2>&1; then
    cm='podman'
  elif command -v docker >/dev/null 2>&1; then
    cm='docker'
  else
    printf 'Podman or Docker need to be installed!\n'
    exit 10
  fi

  $cm pull docker.io/library/node:lts

  $cm run -it --rm \
      -v "${PWD}":/app:Z -w /app \
      node:lts /bin/bash -c 'npm -y create astro@latest . -- --template blog --install --git --typescript strict'
}

create_notes_directory() {
  if [[ -n "${notesDir}" ]]; then
    printf '\nCreate the %s directory\n' "${notesDir}"

    # create the 'notes' directory
    if ! mkdir -p "${notesDir}" ; then
      printf 'Failed to create the %s directory!\n' "${notesDir}"
      return 20
    fi

    # add the 'notes' directory
    gitIgnoreEntries+=("${notesDir}/")
  fi
}

set_gitignore() {
  printf '\nAdd entries to .gitignore\n'
  # add entries to '.gitignore' file
  file='.gitignore'
  for entry in "${gitIgnoreEntries[@]}" ; do
      if ! grep -qxF "${entry}" "${file}" ; then
          echo $'\n# keep local' >> "${file}"
          echo "${entry}" >>"${file}"
      fi
  done
}

modify_package_json() {
  printf '\nModify package.json\n'
  sed -i -E 's/("astro )(dev|preview)"/\1\2 --host"/' package.json
}

download_the_scripts() {
  printf '\nDownload the scripts\n'

  local downloader=''
  if command -v wget >/dev/null 2>&1; then
    downloader='wget'
  elif command -v curl >/dev/null 2>&1; then
    downloader='curl'
  else
      printf 'Either curl or wget are needed to download the scripts!\n' >&2
      exit 30
  fi

  if ! mkdir -p "${scriptDir}"; then
    printf 'Failed to create directory %s !\n' "${scriptDir}" >&2
    exit 31
  fi
  if ! cd "${scriptDir}"; then
    printf 'Failed to cd into %s !\n' "${scriptDir}" >&2
    exit 32
  fi

  for scriptName in "${remoteScriptNames[@]}" ; do
      srcName="${remoteRawRepo}${scriptName}"
      case $downloader in
        curl)
          curl --fail --location --remote-name "${srcName}"
          status=$?
          ;;
        wget)
          wget --no-verbose "${srcName}"
          status=$?
          ;;
        *)
          printf 'No suitable downloader found!\n'
          exit 33
          ;;
      esac
      ((status == 0)) || printf 'Failed to download %s !\n' "${scriptName}"
  done
}

# Check input parameters
[[ $# -eq 0 ]] && { printf 'Pass the name of destination directory as argument!\n' >&2; exit 1; }

dirName="$1"
[[ -z "${dirName}" ]] && { printf 'Name of destination directory is empty!\n' >&2; exit 1; }
[[ -e "${dirName}" ]] && { printf '%s exists!\n' "${dirName}" >&2; exit 1; }

# Create and enter the project's directory
mkdir -p "${dirName}" || { printf 'Failed to create directory %s !\n' "${dirName}" >&2; exit 2; }
cd "${dirName}" || { printf 'Failed to cd into %s !\n' "${dirName}" >&2; exit 3; }

# The main functionality of the script
create_the_project
create_notes_directory
set_gitignore
modify_package_json
download_the_scripts
