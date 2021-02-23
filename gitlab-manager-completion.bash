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

function genericCompletion() {
    mapfile -t COMPREPLY < <(compgen -W "$1" -- "${COMP_WORDS[COMP_CWORD]}")
}

function listCompletion() {
    genericCompletion "$(gitlab-manager | grep ^list | cut -d '[' -f 2 | tr ']' ' ' | tr ':' ' ' | tr ',' ' ')"
}

function cloneCompletion() {
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
        clone | -c)
            cloneCompletion
            return
            ;;
        list | -l)
            listCompletion
            return
            ;;
        -@(cf|-config-file|pf|-projects-file|gcf|-clone-folder|-from))
            _cd
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
