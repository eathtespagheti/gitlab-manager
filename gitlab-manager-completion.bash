#!/usr/bin/env bash
# Copyright (C) 2021 Fabio Sussarellu
#
# This file is part of gitlab-manager.
#
# gitlab-manager is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# gitlab-manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with gitlab-manager.  If not, see <http://www.gnu.org/licenses/>.

function _fileCompletion() {
    local cur
    _init_completion || return
    local IFS='
' i j k
    compopt -o filenames
    if [[ -z ${CDPATH:-} || $cur == ?(.)?(.)/* ]]; then
        _filedir
        return
    fi
    local -r mark_dirs=$(_rl_enabled mark-directories && echo y)
    local -r mark_symdirs=$(_rl_enabled mark-symlinked-directories && echo y)
    for i in ${CDPATH//:/'
'}; do
        k="${#COMPREPLY[@]}"
        for j in $(compgen -d -- "$i/$cur"); do
            if [[ (-n $mark_symdirs && -L $j || -n $mark_dirs && ! -L $j) && ! -d ${j#$i/} ]]; then
                j+="/"
            fi
            COMPREPLY[k++]=${j#$i/}
        done
    done
    _filedir
    if ((${#COMPREPLY[@]} == 1)); then
        i=${COMPREPLY[0]}
        if [[ $i == "$cur" && $i != "*/" ]]; then
            COMPREPLY[0]="${i}/"
        fi
    fi
    return
}

function genericCompletion() {
    mapfile -t COMPREPLY < <(compgen -W "$1" -- "${COMP_WORDS[COMP_CWORD]}")
}

function listCompletion() {
    genericCompletion "$(gitlab-manager | grep ^list | cut -d '[' -f 2 | tr ']' ' ' | tr ':' ' ' | tr ',' ' ')"
}

function projectsPathsCompletion() {
    genericCompletion "$(gitlab-manager -l path | sort | tr '\n' ' ')"
}

function actionsCompletion() {
    genericCompletion "$(gitlab-manager | grep "^[a-z]" | cut -d ',' -f 1 | sort | tr '\n' ' ')"
}

function shortParametersCompletion() {
    genericCompletion "$(gitlab-manager | tr ' ' '\n' | grep "^-[a-z]" | tr ',' ' ' | tr ':' ' ' | sort | tr '\n' ' ')"
}

function longParametersCompletion() {
    genericCompletion "$(gitlab-manager | tr ' ' '\n' | grep "^--[a-z]" | tr ':' ' ' | sort | tr '\n' ' ')"
}

_gitlab-manager_completions() {
    numberOfWords="${#COMP_WORDS[@]}"
    prevParameterIndex="$((numberOfWords - 2))"

    # Switch based on what's user writing
    case "${COMP_WORDS[COMP_CWORD]}" in
    --*)
        # Long parameters completion
        longParametersCompletion
        return
        ;;
    -*)
        # Short parameter completion
        shortParametersCompletion
        return
        ;;
    *)
        case "${COMP_WORDS[prevParameterIndex]}" in
        clone | -c | -d | delete)
            projectsPathsCompletion
            return
            ;;
        list | -l)
            listCompletion
            return
            ;;
        -@(gcf|-clone-folder|-from))
            _cd
            return
            ;;
        -@(cf|-config-file|pf|-projects-file))
            _fileCompletion
            return
            ;;
        --visibility)
            genericCompletion "$(gitlab-manager | grep "\--visibility" | sed "s/--/\n/g;s/[[,:]//g" | tr ']' ' ' | grep visibility | cut -d ' ' -f 2-4)"
            return
            ;;
        *)
            actionsCompletion
            ;;
        esac
        ;;
    esac
}

complete -F _gitlab-manager_completions gitlab-manager
