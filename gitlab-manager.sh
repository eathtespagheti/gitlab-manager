#!/usr/bin/env sh
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

# shellcheck disable=SC1090

CONFIG_FILE_NAME="gitlab-manager.config"
DATA_FOLDER_NAME="gitlab-manager"
PROJECTS_FILE_NAME="projects.json"
API_ROOT="https://gitlab.com/api/v4"
ACTION="help"
ARG=""

printHelp() {
    printf "Actions:\n\n"
    printf "%s:\n\t%s\n" "clone, -c <repo-path>" "Clone repo"
    printf "%s:\n\t%s\n" "delete, -d <repo-path>" "Delete a repo"
    printf "%s:\n\t%s\n" "list, -l [name, description, path, url, id]" "List all repos, optionally you can specify to list only a specific field for every project"
    printf "%s:\n\t%s\n" "new, -n --name \"A quoted name\" --description \"A quoted description\" --path <path> --from local/repo/path --visibility [private, internal, public]" "Create a new repository on gitlab in the specified workspace/name, you can create it from a local repository with the --from parameter"
    printf "%s:\n\t%s\n" "search, -s <word>" "Search between projects, to search a phrase double quote it"
    printf "%s:\n\t%s\n" "update, -u" "Update projects list"
    printf "\nParameters:\n\n"
    printf "%s:\n\t%s\n" "-h, --help" "Print this message"
    printf "%s:\n\t%s\n" "-v, --verbose" "Enable verbose mode"
    printf "%s:\n\t%s\n" "-ui, --user-id <user id>" "Set USER_ID"
    printf "%s:\n\t%s\n" "-pt, --private-token <token>" "Set PRIVATE_TOKEN"
    printf "%s:\n\t%s\n" "-cf, --config-file <path/to/config/file>" "Use a different config file"
    printf "%s:\n\t%s\n" "-pf, --projects-file <path/to/projects/file>" "Use a different projects file"
    printf "%s:\n\t%s\n" "-gcf, --clone-folder <path/to/clone/folder>" "Clone git projects in the specified folder"
    exit 0
}

info() {
    [ -n "$VERBOSE" ] && echo "$@"
}

parseNewArgs() {
    toShift=""
    : $((toShiftBack = 0))
    : $((toShift = 0))
    for arg in "$@"; do
        case "$arg" in
        --name)
            shift
            newName="$1"
            toShift="1"
            ;;
        --description)
            shift
            newDescription="$1"
            toShift="1"
            ;;
        --path)
            shift
            newPath="$1"
            toShift="1"
            ;;
        --from)
            shift
            newFrom="$1"
            toShift="1"
            ;;
        --visibility)
            shift
            newVisibility="$1"
            toShift="1"
            ;;
        *)
            [ "$toShift" = "0" ] && toShift="$toShiftBack" && return
            [ $((toShift)) -gt 0 ] && {
                shift
                : $((toShift = toShift - 1))
                : $((toShiftBack = toShiftBack + 1))
            }
            ;;
        esac
        : $((toShiftBack = toShiftBack + 1))
    done
    toShift="$toShiftBack"
}

parseArgs() {
    : $((toShift = 0))
    for arg in "$@"; do
        case "$arg" in
        -v | --verbose)
            VERBOSE="true"
            info "Enable Verbose"
            shift
            ;;
        -ui | --user-id)
            shift
            USER_ID="$1"
            toShift="1"
            info "Set user id to $USER_ID"
            ;;
        -pt | --private-token)
            shift
            PRIVATE_TOKEN="$1"
            toShift="1"
            info "Set private token to $PRIVATE_TOKEN"
            ;;
        -cf | --config-file)
            shift
            CONFIG_FILE="$1"
            toShift="1"
            info "Use $CONFIG_FILE as config file"
            ;;
        -pf | --projects-file)
            shift
            PROJECTS_FILE="$1"
            toShift="1"
            info "Use $PROJECTS_FILE as projects file"
            ;;
        -gcf | --clone-folder)
            shift
            PROJECTS_FOLDER="$1"
            toShift="1"
            info "Use $PROJECTS_FOLDER as destination for cloned projects"
            ;;
        -h | --help)
            printHelp
            shift
            ;;
        -c | clone)
            ACTION="clone"
            shift
            ARG="$1"
            toShift="1"
            ;;
        -d | delete)
            ACTION="delete"
            shift
            ARG="$1"
            toShift="1"
            ;;
        -l | list)
            ACTION="list"
            shift
            ARG="$1"
            toShift="1"
            ;;
        -n | new)
            ACTION="new"
            shift
            parseNewArgs "$@"
            ;;
        -s | search)
            ACTION="search"
            shift
            ARG="$1"
            toShift="1"
            ;;
        -u | update)
            ACTION="update"
            shift
            ;;
        *)
            [ "$toShift" = "0" ] && {
                printf "Unrecognized parameter or action: %s\n\n" "$arg"
                printHelp
            }
            [ $((toShift)) -gt 0 ] && {
                shift
                : $((toShift = toShift - 1))
            }
            ;;
        esac
    done
}

checkDependencies() {
    command -v curl >/dev/null 2>&1 || {
        echo "curl not installed"
        exit 3
    }
    command -v jq >/dev/null 2>&1 || {
        echo "jq not installed"
        exit 3
    }
}

initPaths() {
    [ -z "$XDG_CONFIG_HOME" ] && XDG_CONFIG_HOME="$HOME/.config"
    CONFIG_FILE="$XDG_CONFIG_HOME/$CONFIG_FILE_NAME"

    [ -z "$XDG_DATA_HOME" ] && XDG_DATA_HOME="$HOME/.local/share"
    DATA_FOLDER="$XDG_DATA_HOME/$DATA_FOLDER_NAME"
    PROJECTS_FILE="$DATA_FOLDER/$PROJECTS_FILE_NAME"

    [ -z "$PROJECTS_FOLDER" ] && PROJECTS_FOLDER="."

    [ ! -d "$DATA_FOLDER" ] && {
        info "Creating data folder in $DATA_FOLDER"
        mkdir -p "$DATA_FOLDER"
    }
}

checkUserVariables() {
    [ -n "$USER_ID" ] || [ -n "$PRIVATE_TOKEN" ]
}

loadConfigFile() {
    [ ! -f "$CONFIG_FILE" ] && {
        info "Config file doesn't exist"
        checkUserVariables || exit 1
    }
    info "Loading config file"
    . "$CONFIG_FILE" # Source config file only if user variables aren't already set
}

updateProjectsList() {
    info "Updating projects list in $PROJECTS_FILE"
    if [ -n "$PRIVATE_TOKEN" ]; then
        request="$API_ROOT/projects?min_access_level=10"
        info "Retrieving public projects from $request"
        curl --header "Authorization: Bearer $PRIVATE_TOKEN" "$request" -o "$DATA_FOLDER/public.json" --fail --silent --show-error || {
            echo "Error getting projects from API"
            exit 2
        }
        request="$request&visibility=private"
        info "Retrieving private projects from $request"
        curl --header "Authorization: Bearer $PRIVATE_TOKEN" "$request" -o "$DATA_FOLDER/private.json" --fail --silent --show-error || {
            echo "Error getting projects from API"
            exit 2
        }
    elif [ -n "$USER_ID" ]; then
        request="$API_ROOT/users/$USER_ID/projects"
        info "Retrieving public projects from $request"
        curl "$request" -o "$DATA_FOLDER/public.json" --fail --silent --show-error || {
            echo "Error getting projects from API"
            exit 2
        }
        request="$request?visibility=private"
        info "Retrieving private projects from $request"
        curl --header "Authorization: Bearer $PRIVATE_TOKEN" "$request" -o "$DATA_FOLDER/private.json" --fail --silent --show-error || {
            echo "Error getting projects from API"
            exit 2
        }
    else
        echo "No User ID or Private Token provided!"
        exit 4
    fi

    info "Merging public and private projects"
    jq -scf "$DATA_FOLDER/public.json" "$DATA_FOLDER/private.json" | jq ".[]" >"$PROJECTS_FILE"
    rm "$DATA_FOLDER/public.json" "$DATA_FOLDER/private.json"
}

printProject() {
    [ -n "$2" ] && {
        case "$2" in
        name)
            field=1
            ;;
        description)
            field=2
            ;;
        path)
            field=3
            ;;
        url)
            field=4
            ;;
        id)
            field=5
            ;;
        esac
    }
    if [ -z "$field" ]; then
        name=$(echo "$1" | cut -f 1)
        description=$(echo "$1" | cut -f 2)
        path=$(echo "$1" | cut -f 3)
        url=$(echo "$1" | cut -f 4)
        printf "Name: %s\nDescrption: %s\nPath: %s\nURL: %s\n\n" "$name" "$description" "$path" "$url"
    else
        echo "$1" | cut -f "$field"
    fi
}

fromJsonToList() {
    jq -r "[.name, .description, .path_with_namespace, .ssh_url_to_repo, .id] | @tsv" "$PROJECTS_FILE"
}

checkProjects() {
    info "Checking if projects file exist"
    [ ! -f "$PROJECTS_FILE" ] && updateProjectsList
}

listProjects() {
    checkProjects
    fromJsonToList |
        while IFS="" read -r line || [ -n "$line" ]; do
            printProject "$line" "$1"
        done
}

searchProject() {
    checkProjects
    fromJsonToList | grep "$1" |
        while IFS="" read -r line || [ -n "$line" ]; do
            printProject "$line"
        done
}

cloneProject() {
    URL=$(fromJsonToList | grep -w "$1" | cut -f 4)
    info "Cloning $1 from url $URL"
    git -C "$PROJECTS_FOLDER" clone --recurse-submodules "$URL"
}

newProject() {
    [ -z "$newPath" ] && [ -z "$newName" ] && {
        [ -z "$newFrom" ] && echo "No path or name specified for new project!" && exit 5
        info "Extracting project name from $newFrom"
        newName="$(basename "$newFrom")"
    }

    [ -n "$newName" ] && forLater="$newName" && newName="name=$newName"
    [ -n "$newPath" ] && forLater="$newPath" && newPath="path=$newPath"
    [ -n "$newDescription" ] && newDescription="&description=$newDescription"
    [ -n "$newVisibility" ] && newVisibility="&visibility=$newVisibility"
    [ -n "$newName" ] && [ -n "$newPath" ] && newPath="&$newPath"

    if [ -n "$PRIVATE_TOKEN" ]; then
        request="$API_ROOT/projects"
        newData="$newName$newPath$newDescription$newVisibility"
        info "Creating new project with $request and data $newData"
        curl --header "Authorization: Bearer $PRIVATE_TOKEN" -X POST -d "$newData" "$request" --fail --silent --show-error || {
            echo "Error creating project API"
            exit 6
        }
    fi

    updateProjectsList

    [ -n "$newFrom" ] && [ -d "$newFrom" ] && {
        info "Searching new project url with $forLater"
        URL=$(fromJsonToList | grep -w "$forLater" | cut -f 4)
        info "Found url $URL"
        git -C "$newFrom" remote show | grep -w ^origin >/dev/null 2>&1 && {
            info "Removing old origin"
            git -C "$newFrom" remote remove origin
        }
        git -C "$newFrom" remote add origin "$URL"
        git -C "$newFrom" push -u origin --all
        git -C "$newFrom" push -u origin --tags
    }

    return 0
}

deleteProject() {
    ID=$(fromJsonToList | grep -w "$1" | cut -f 5)
    info "Deleting $1 with id $ID"
    request="$API_ROOT/projects/$ID"
    curl --header "Authorization: Bearer $PRIVATE_TOKEN" --request DELETE "$request" --fail --silent --show-error || {
        echo "Error deleting project"
        exit 7
    }
    updateProjectsList
}

execAction() {
    case "$ACTION" in
    list)
        listProjects "$ARG"
        ;;
    help)
        printHelp
        ;;
    clone)
        cloneProject "$ARG"
        ;;
    update)
        updateProjectsList
        ;;
    search)
        searchProject "$ARG"
        ;;
    new)
        newProject
        ;;
    delete)
        deleteProject "$ARG"
        ;;
    *)
        listProjects
        ;;
    esac

}

initPaths
checkDependencies
loadConfigFile
parseArgs "$@"
execAction
