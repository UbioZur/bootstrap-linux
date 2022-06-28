#!/usr/bin/env bash

## ---------------------------------------
## 
##   UbioZur / ubiozur.tk
##        https://git.ubiozur.tk
##
## Script name : Common Library
## Description : Common functions used for the bootstrap-linux installs
## Dependencies: ssh-agent, loglib.sh, utilslib.sh, envlib.sh
## Repository  : https://github.com/UbioZur/bootstrap-linux
## License     : https://github.com/UbioZur/bootstrap-linux/LICENSE
##
## ---------------------------------------

## ---------------------------------------
##   Variables to tweak the lib
## _TMP_DIR: Full path of the temporary directory.
## _PKG_MNG: Package manager command.
##
##   Functions to use the lib
## _create_temp_dir         : Create the temporary directory $_TMP_DIR.
## _delete_temp_dir         : Delete and clean the temporary directory.
## _create_folder           : Create a folder and it's parent and track that creation.
## _cleanup_folders         : Deletes the folders created by _create_folder if they are not empty.
## _ensure_ssh_agent        : Ensure an ssh-agent is runing.
## _distro_is_supported     : Check that the distribution is supported.
## _set_pkgmng              : Set the _PKG_MNG Variable to the package manager command.
## _display_os_information  : Display information about the OS.
## _display_hdwr_information: Display information about the hardware.
## _display_user_information: Display information about the user.
## _crontab_list            : Make crontab -l not exit with code 1 if there is no entry.
## _multiline_log           : log multiple lines.
## _copy_as_root            : Copy a file as root.
## _dnfrepo_is_enabled      : Check if a dnf repo is enabled.
## _dnfrepo_is_disabled     : Check if a dnf repo is disabled.
## ---------------------------------------

## ---------------------------------------
##   Functions and global variables that should not be used by
## external programs should start with a __ (Double underscore).
## ---------------------------------------

# Avoid lib to be sourced more than once, Rename the Variable to a unique one.
[[ "${__COMMON_LIBLOADED:-""}" == "yes" ]] && return 0
readonly __COMMON_LIBLOADED="yes"

# If lib is run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

# Get the Lib file path and directory, Rename the Variable to a unique one.
readonly __COMMON_LIB_FILE="$( readlink -f "$BASH_SOURCE" )"
readonly __COMMON_LIB_DIR="$( dirname "$(readlink -f "${BASH_SOURCE}")" )"

# Source my loglib library if used
source "${__COMMON_LIB_DIR}/loglib.sh"
# Source my utils library if used
source "${__COMMON_LIB_DIR}/utilslib.sh"
# Source my env library if used
source "${__COMMON_LIB_DIR}/envlib.sh"

# Set the temp directory 
_TMP_DIR="${_TMP_DIR-"/tmp/deploy"}"

# Set the packages manager variable
_PKG_MNG="${_PKG_MNG-}"

# Variables to save the list of folders created (useful for DRY_RUN)
declare -a __FOLDER_LIST=()


## ---------------------------------------
##   Create the temp directory
## Usage: _create_temp_dir
## ---------------------------------------
function _create_temp_dir {
    _log log "Creating temp directory '$_TMP_DIR'"
    mkdir -p "$_TMP_DIR"
}

## ---------------------------------------
##   Delete the temp directory
## Usage: _delete_temp_dir
## ---------------------------------------
function _delete_temp_dir {
    #_log log "Deleting temp directory '$_TMP_DIR'"
    rm -rf "$_TMP_DIR"
}

## ---------------------------------------
##   Create a folder (and it's parent if needed) and add it to the list.
## The list is important for cleaning up (especially in Dry Run mode)
## $@: list of folders to create
## Usage: create_folder "di1" "dir2"
## ---------------------------------------
function _create_folder {
    # Make sure we have at least 1 argument!
    [[ $# -eq 0 ]] && die "No arguments passed to \"create_folder\""

    mkdir -p "$@"
    _FOLDER_LIST=( "${__FOLDER_LIST[@]}" "$@" )
}

## ---------------------------------------
##   Clean up the list of folders (if empty) and their parents
## it use the list of folders created by create_folder
## Usage: cleanup_folders
## ---------------------------------------
function _cleanup_folders {
    for dir in "${__FOLDER_LIST[@]}"
    do
        [[ -d "$dir" ]] && __nofail_rmdir "$dir"
    done
}

## ---------------------------------------
##   Recursively remove empty directories
## No Program fail (no exit code except 0)
## Usage: nofail_rmdir
## ---------------------------------------
function __nofail_rmdir {
    rmdir -p --ignore-fail-on-non-empty "$@" || test $? = 1;
}

## ---------------------------------------
##   Create a ssh-agent if it doesn't exist
## Usage: _ensure_ssh_agent
## ---------------------------------------
function _ensure_ssh_agent {
    local -r agentpid="$( pgrep -u "$USER" ssh-agent )"
    if [[ -z $agentpid ]]; then
        _log log "Creating a ssh-agent..."
        eval $( ssh-agent )
        return
    fi
    _log log "Using ssh-agent pid: $agentpid"
}

## ---------------------------------------
##   Check that the distribution is supported
## Usage: _distro_is_supported
## ---------------------------------------
function _distro_is_supported {
    if _is_fedora; then
        _log suc "Distribution is supported."
        return
    fi

    __warning "The Following distributions are supported: 'Fedora'."
    die "The distribution '$( _os_name )' is not supported!"
}

## ---------------------------------------
##   Set the $PKGMNG variable to the package manager of the distro
## Usage: _set_pkgmng
## ---------------------------------------
function _set_pkgmng {
    [[ ! -z $_PKG_MNG ]] && return
    if _is_fedora; then _PKG_MNG="sudo dnf --assumeyes --color=always" ; return; fi
    if _is_debian; then _PKG_MNG="sudo apt-get --no-install-recommends --assume-yes" ; return; fi

    die "Something is strange in _set_pkgmng!"
}

## ---------------------------------------
##   Display OS information
## Usage: _display_os_information
## ---------------------------------------
function _display_os_information {
    _log log "Distro: $( _os_name )"
    _log log "Distro Version: $( _os_version) "
    _log log "Kernel: $( _os_kernel )"
    _log log "Hostname: $( _os_hostname )"
}

## ---------------------------------------
##   Display Hardware information
## Usage: _display_hdwr_information
## ---------------------------------------
function _display_hdwr_information {
    _log log "CPU Model Name: $( _cpu_model )"
    _log log "CPU Vendor: $( _cpu_vendor) "
    _log log "CPU Cores: $( _cpu_cores )"
    _log log "CPU Threads: $( _cpu_threads )"
    _log log "RAM: $( _mem_total )"
    _log log "$( _multiline_log "GPU: $( _gpu_count ) GPU(s) found." "$( _gpu_list )" )" 
}

## ---------------------------------------
##   Display User information
## Usage: _display_user_information
## ---------------------------------------
function _display_user_information {
    local priv="no"
    if _has_sudo; then priv="yes"; fi

    _log log "User: $USER"
    _log log "Home: $HOME"
    _log log "Priviledged: $priv"
    _log log "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME-"Not Set!"}"
    _log log "XDG_PROJECTS_DIR: ${XDG_PROJECTS_DIR-"Not Set!"}"
    _log log "SSHHOME: ${SSHHOME-"Not Set!"}"
    _log log "GNUPGHOME: ${GNUPGHOME-"Not Set!"}"
}

## ---------------------------------------
##   List a crontab without exiting to 1 
## Usage: __crontab_list "Thing to crontab list"
## ---------------------------------------
function _crontab_list {
    crontab -l "$@" || test $? = 1;
}

## ---------------------------------------
##   Get a string to log a multiline
## $1: The message to display on the first line
## $2: the multiline to display
## Usage: _multiline_log "msg" "multiline"
## ---------------------------------------
function _multiline_log {
    local msg="${1-"No Messages to display!"}"
    local -r ml="${2-"No multilines to log!"}"

    # change delimiter (IFS) to new line.
    IFS_BAK=$IFS
    IFS=$'\n'
    # Print each lines
    for line in $ml; do msg="${msg}\n${LOG_LEFT_MARGIN}- ${line}"; done
    # return delimiter to previous value
    IFS=$IFS_BAK
    IFS_BAK=

    # return the string for the information
    echo "${msg}"
}

## ---------------------------------------
##   Copy a file as root and make sure the permissions are set
## $1: src file to copy
## $2: dst file to copy
## $3: permission. Default (644)
## Usage: _copy_as_root "src" "dst" ["644"]
## ---------------------------------------
function _copy_as_root {
    local -r src="${1-}"
    local -r dst="${2-}"
    local -r perm="${3-644}"
    
    # Check that the src and dst are not null or empty!
    if [[ -z "$src" ]]; then _log fai "_copy_as_root: Source files is an empty path!"; return; fi
    if [[ -z "$dst" ]]; then _log fai "_copy_as_root: Destination files is an empty path!"; return; fi
    # Check that src file exist!
    if [[ ! -f "$src" ]]; then _log fai "_copy_as_root: Source files '$src' is not a file!"; return; fi

    # Make sure destination folder exist
    _run "sudo mkdir -p $( dirname $dst )"

    # Copy file and set permissions
    _run "sudo cp $src $dst"
    _run "sudo chown root:root $dst"
    _run "sudo chmod $perm $dst"
}

## ---------------------------------------
##   Check if a DNF repository is enabled.
## $1: The name of the repository
## Usage: _dnfrepo_is_enabled "reponame"
## ---------------------------------------
function _dnfrepo_is_enabled {
    local count=$($_PKG_MNG repolist enabled | _my_grep $1 | wc -l 2> /dev/null)

    [[ $count -gt 0 ]] && return
    false
}

## ---------------------------------------
##   Check if a DNF repository is disabled.
## $1: The name of the repository
## Usage: _dnfrepo_is_disabled "reponame"
## ---------------------------------------
function _dnfrepo_is_disabled {
    local count=$($_PKG_MNG repolist disabled | _my_grep $1 | wc -l 2> /dev/null)

    [[ $count -gt 0 ]] && return
    false
}

## ---------------------------------------
##   Get a git repository.
## $1: Git URL
## $2: local folder.
## $3: Branch (Default master)
## Usage: _get_git_repo "git@gitprov.com:user/repo.git" "$HOME/myrepo" [master]
## ---------------------------------------
function _get_git_repo {
    local -r repo="${1-}"
    local -r dst="${2-}"
    local -r brch="${3-"master"}"
    
    # Check that the repo and dst are not null or empty!
    if [[ -z "$repo" ]]; then _log fai "_get_git_repo: Repository is an empty url!"; return; fi
    if [[ -z "$dst" ]]; then _log fai "_get_git_repo: Destination is an empty path!"; return; fi
    
    # If the repo doesn't exist in the system, then clone it.
    if [[ ! -d "$dst/.git" ]]; then
        _run "git clone --depth 500 ${repo} ${dst}"
        _log suc "Repository '$repo' cloned to '$dst'"
        return
    fi
    
    _log war "'$dst' is already a git repo, modifying it to match the new repo!"
    # Checking if the git already have a remote origin
    local repo_cmd="git -C $dst remote add origin $repo"
    local remote_count="$(git -C $dst remote -v | _my_grep origin | wc -l)"
    if [ $remote_count -gt 0 ]; then
        _log war "'$dst' already have an 'origin' remote. Changing it!"
        repo_cmd="git -C $dst remote set-url origin $repo"
    fi
    _run "$repo_cmd"

    _run "git -C $dst fetch --depth=500" 
    _run "git -C $dst checkout -f $brch"
    _run "git -C $dst branch --set-upstream-to=origin/$brch $brch"
    _run "git -C $dst pull"

    _log suc "Repository '$repo' initialized to '$dst'"
}