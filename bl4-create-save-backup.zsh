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

function write_none() {
    printf -- '\n'
}

function write_header() {
    printf "\n##\n## ${1}\n##\n\n" "${@:2}"
}

function main() {
    local save_path="$(${${${(%):-%x}:a}:h}/bl4-resolve-save-directory-path.zsh)"
    local back_path="${save_path}_$(date +%Y%m%d\-%H%M%S)"

    if [[ -e "${back_path}" ]]; then
        write_error 'Backup path ("%s") already exists! Not overwriting. Stopping.' "${back_path}"
        exit 1
    fi

    write_header 'PERFORMING BACKUP'
    write_info 'Backing up "%s" to "%s" ...' "${save_path}" "${back_path}"
    write_none

    if ! cp -av "${save_path}" "${back_path}"; then
        write_none
        write_error 'Failed to back up some saves!!!!!'
        exit 1
    fi

    write_none
    write_info 'Operation completed!'
}

main "${@}"