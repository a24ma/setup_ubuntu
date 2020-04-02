#!/usr/bin/env bash

on_failed() { 
    echo "failed on $1"; rm -f out
    exit 1
}

require() {
    if [[ -z "$(eval "echo \$${1:?}")" ]]; then
        on_failed "undefined:$1"
    fi
}

edit_with_backup() {
    require top_id
    usage="usage: $0 <edit_path> <setup_id> <backup_id> <comment_str> (REQUIRE: 'out' is required to be appended to existing edit_path.)"
    edit_path="${1:?$usage}" # MUST exist.
    setup_id="${2:?$usage}"
    backup_id="${3:?$usage}"
    comment_str="${4:?$usage}"
    if [ ! -f out ]; then echo "[ERROR] 'out' not found."; return 1; fi
    if [ -w "$edit_path" ]; then
        cpcmd="cp"
    elif sudo [ -w "$edit_path" ]; then 
        cpcmd="sudo cp"
    else
        echo "[ERROR] '$edit_path' not found or unwritable."; return 1;
    fi
    tag="${top_id}_${setup_id}"
    sed "/^${comment_str} <${tag}>/,/^${comment_str}<\/${tag}>/d" "$edit_path" > _out
    cat out >> _out
    touch -t "0001010000.00" ~/$top_id/backup/${backup_id}_dummy
    latest_backup="$(ls -t ~/$top_id/backup/${backup_id}* | head -1)"
    if diff -q "$edit_path" "$latest_backup"; then :; else
        cp -f "$edit_path" ~/$top_id/backup/${backup_id}${baksuf}
    fi
    $cpcmd -f _out "$edit_path"
    rm -f out _out
}
