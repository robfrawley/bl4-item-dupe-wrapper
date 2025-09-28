#!/usr/bin/env zsh

set -o allexport
source "${${${(%):-%x}:a}:h}/.env.local" || source "${${${(%):-%x}:a}:h}/.env"
set +o allexport

function write_error() {
    printf -- "!! Error: ${1}\n" "${@:2}"
}

function write_info() {
    printf -- "-> ${1}\n" "${@:2}"
}

function write_header() {
    printf "\n##\n## ${1}\n##\n\n" "${@:2}"
}

function is_package_installed() {
    dpkg-query -W -f='${Status}' "${1}" 2> /dev/null | grep -q "install ok installed" &> /dev/null
}

function install_package() {
    if is_package_installed "${1}"; then
        write_info 'Package "%s" ... FOUND' "${1}"
    else
        write_info 'Package "%s" ... INSTALLING' "${1}"
        sudo apt install -y "${1}"
    fi
}

function req_deps() {
    write_header "CHECKING PACKAGE DEPENDENCIES"
    install_package python3
    install_package python3-virtualenv
    install_package git
    install_package yq
}

function env_make() {
    local venv_path="${1}"
    local venv_incs="${2}"
    local call_path="${3}"
    local call_http="${4}"

    write_header "CHECKING PYTHON ENVIRONMENT"
    
    if [[ ! -e "${venv_path}" ]] || [[ ! -f "${venv_incs}" ]] || [[ ! -e "${call_path}" ]]; then
        write_info 'Creating new Python virtual environment ("%s").' "${venv_path}"
        if ! python3 -m virtualenv "${venv_path}"; then
            write_error 'Failed to create virtual environment! Halting.'
            exit 1
        fi

        git clone "${call_http}" "${call_path}"
        . "${venv_incs}"
        pip install -r "${call_path}/requirements.txt"
    fi

    write_info 'Found Python virtual environment ("%s").' "${venv_path}"
}

function main() {
    local save_index="${1:-99}"
    local dupe_count="${2:-1}"
    local save_path="$(${${${(%):-%x}:a}:h}/bl4-resolve-save-directory-path.zsh)"
    local save_file
    local yaml_file
    local dupe_file
    local venv_path="${HOME}/bl4/venv"
    local venv_incs="${venv_path}/bin/activate"
    local call_http="https://github.com/glacierpiece/borderlands-4-save-utility"
    local call_path="${HOME}/bl4/save-decrypter"
    local call_file="${call_path}/blcrypt.py"
    local inventory
    local size_init
    local size_dupe
    local inv_duped
    local serial_ls

    if [[ ${#} -lt 1 ]]; then
        printf 'USAGE: ${0} <SAVE-INDEX> [DUPE-NUMBER]\n'
        exit 0
    fi

    req_deps
    env_make "${venv_path}" "${venv_incs}" "${call_path}" "${call_http}"
    . "${venv_incs}"

    if [[ "${dupe_count}" -lt 1 ]]; then
        write_error 'Duplicate count must be a positive integer (1 or greater).'
        return 1
    fi

    if [[ ! -e "${save_path}" ]]; then
        write_error 'Invalid BL4 save directory path ("%s"). Ensure "WINDOWS_USERNAME" and "STEAM_ID" are properly set. Currently only support Steam saves.' "${save_path:-<NULL>}"
        return 1
    fi

    save_file="${save_path}/${save_index}.sav"
    yaml_file="${save_path}/${save_index}.yaml"
    dupe_file="${save_path}/${save_index}_duped.yaml"

    if [[ ! -f "${save_file}" ]]; then
        write_error 'Invalid BL4 save file path ("%s"). Ensure you passed the correct character index to the script when invoking it.' "${save_file}"
        return 1
    fi

    zsh "${${${(%):-%x}:a}:h}/bl4-create-save-backup.zsh"

    write_header "DUPLICATING INVENTORY"

    if ! python "${call_file}" decrypt -in "${save_file}" -out "${yaml_file}" -id "${STEAM_ID}"; then
        write_error 'Failed to execute external command to decrypt save file ("%s").' "${save_file}"
        return 1
    fi

    if [[ ! -f "${yaml_file}" ]]; then
        write_error 'Failed to decode the save file ("%s") into a plaintext YAML file ("%s").' "${save_file}" "${yaml_file}"
        return 1
    fi

    inventory="$(yq '.state.inventory.items.backpack' "${yaml_file}" 2> /dev/null | head -n-1 | tail -n+2)"
    size_init="$(echo "${inventory}" | grep -oE '\bslot_[0-9]+\b' | wc -l)"

    if [[ -z "${inventory}" ]]; then
        write_error 'Inventory appears to be empty in save file ("%s").' "${save_file}"
        return 1
    fi

    inv_duped="$(printf '{\n%s' "${inventory}")"

    if [[ "${dupe_count}" -ge 2 ]]; then
        for i in $(seq 2 ${dupe_count}); do
            inv_duped="$(printf '%s,\n %s' "${inv_duped}" "${inventory}")"
        done
    fi

    inv_duped="$(printf '%s\n}' "${inv_duped}" | awk '{
        if ($0 ~ /"slot_[0-9]":/) {
            sub(/slot_[0-9]/, "slot_" i, $0)
            i++
        }
        print
        }' i=0
    )"
    size_dupe="$(echo "${inv_duped}" | grep -oE '\bslot_[0-9]+\b' | wc -l)"

    yq '.state.inventory.items.backpack = '"$(echo "${inv_duped}" | jq -c .)" "${yaml_file}" > "${dupe_file}"

    if ! python "${call_file}" encrypt -in "${dupe_file}" -out "${save_file}.new" -id "${STEAM_ID}"; then
        write_error 'Failed to execute external command to encrypt duped yaml file ("%s").' "${dupe_file}"
        return 1
    fi

    mv -v "${save_file}" "${save_file}.old_$(date +%Y%m%d%H%M%S)"
    mv -v "${save_file}.new" "${save_file}"

    printf '\n'
    write_info 'Started with %d inventory items; new files has %d.' "${size_init}" "${size_dupe}"
}

main "${@}"