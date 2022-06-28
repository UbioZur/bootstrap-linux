#!/usr/bin/env bash

## ---------------------------------------
## 
##   UbioZur / ubiozur.tk
##        https://git.ubiozur.tk
##
## Script name : Utility Library
## Description : A helper bash library to get useful functions.
## Dependencies:
## Repository  : https://github.com/UbioZur/templates
## License     : https://github.com/UbioZur/templates/LICENSE
##
## ---------------------------------------

## ---------------------------------------
##   Variables to tweak the lib
## DRY_RUN: run the script in Dry run mode. Display instead of running all command starting with _run
##
##   Functions to use the lib
## _my_grep arg     : Utility grep to use in place of grep inside scripts 
## _run cmd logcmd  : To allow a command (cmd) to be dry run, logcmd is optional (ex: "log dry").
## _template        : Create a stream (to push to a file with >) from a template file.
## _die msg exit    : Exit the program with an exit code displaying an error message.
## _is_root         : Check if the user is root.
## _has_sudo        : Check if the user has sudo/wheel priviledge through groups.
## ---------------------------------------

## ---------------------------------------
##   Functions and global variables that should not be used by
## external programs should start with a __ (Double underscore).
## ---------------------------------------

# Avoid lib to be sourced more than once.
[[ "${__UTILSLIBLOADED:-""}" == "yes" ]] && return 0
readonly __UTILSLIBLOADED="yes"

# If lib is run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

# Get the Lib file path and directory.
readonly __UTILSLIB_FILE="$( readlink -f "$BASH_SOURCE" )"
readonly __UTILSLIB_DIR="$( dirname "$(readlink -f "${BASH_SOURCE}")" )"

# Useful if wanted to run a script in dry run mode.
DRY_RUN="${DRY_RUN-0}"


## ---------------------------------------
##   Grep wrapper to catch return code error when using 
## with set -eo pipefail.
## args: same as for the grep command
## Usage: _my_grep "Thing to grep"
## ---------------------------------------
function _my_grep { 
    grep "$@" || test $? = 1;
}

## ---------------------------------------
##   Run or dry run (display) a command
## $1: the command to run or dry run
## $2: OPTIONAL, the display command to use in dry run. Default: "_log dry" or "echo" 
## Usage: _run "command to run" ["display command"]
## ---------------------------------------
function _run {
    local -r cmd="${1-"No Command!"}"
    # use "_log dry" if loglib is loaded or echo to display as default
    local defdisplay="echo"
    [[ $(type -t _log) == function ]] && defdisplay="_log dry"
    local -r display="${2-"$defdisplay"}"
    # If not in dry run, do the command!
    if [[ ${DRY_RUN} = 0 ]]; then 
        $cmd
        return
    fi

    # If in Dry run, Display the command
    $display "$cmd"
}


## ---------------------------------------
##   Create a dest file by filing the template source with the variables
## $1: the source template file value to fill in file is "${grub_timeout-5}" Just like a bash variable with default
## Usage: _template mytemplate.txt > dest.txt
## ---------------------------------------
function _template {
    eval "cat <<EOF
$(<$1)
EOF
    " 2> /dev/null
}

## ---------------------------------------
##   Exit the program with an error
## $1: The error message to show
## $2: OPTIONAL, te exit code. Default: 1 
## Usage: _die "msg" 1
## ---------------------------------------

## Exit the script after an error!
####
function _die {
    local -r msg="${1-"Exiting with an Error"}"
    local -r code=${2-1} # default exit status 1

    # if loglib is loaded, then use the log function
    [[ $(type -t _log) == function ]] && _log err "$msg" || echo "$msg"
    exit $code
}

## ---------------------------------------
##   Check if the user is root 
## Usage: if _is_root; then ... fi
## ---------------------------------------
function _is_root {
    [[ $(id -u) = 0 ]] && return
    false
}

## ---------------------------------------
##   Check if the user has sudo priviledges 
## Usage: if _has_sudo; then ... fi
## ---------------------------------------
function _has_sudo {
    [[ $( groups $USER | _my_grep 'sudo\|wheel' | wc -l ) -gt 0 ]] && return
    false
}
