#!/usr/bin/env zsh

set -o allexport
source "${${${(%):-%x}:a}:h}/.env.local" || source "${${${(%):-%x}:a}:h}/.env"
set +o allexport

function first_valid_path() {
    for p in "${@}"; do
        if [[ -e "${p}" ]]; then
            echo "${p}"
            return 0
        fi
    done
}

function main() {
    local windows_username="${WINDOWS_USERNAME:-${USER}}"
    local steam_id="${STEAM_ID}"
    local -a save_path_roots=(
        "/mnt/c/Users/${windows_username}/Documents/My Games/Borderlands 4/Saved/SaveGames/${steam_id}/Profiles/client"
        "/mnt/c/Users/${windows_username}/OneDrive/Documents/My Games/Borderlands 4/Saved/SaveGames/${steam_id}/Profiles/client"
    )

    printf '%s' "$(first_valid_path "${save_path_roots[@]}")"
}

main "${@}"