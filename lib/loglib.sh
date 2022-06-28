#!/usr/bin/env bash

## ---------------------------------------
## 
##   UbioZur / ubiozur.tk
##        https://git.ubiozur.tk
##
## Script name : loglib
## Description : A helper bash library to log your script.
## Dependencies:
## Repository  : https://github.com/UbioZur/templates
## License     : https://github.com/UbioZur/templates/LICENSE
##
## ---------------------------------------

## ---------------------------------------
##   Variables to tweak the lib
## LOG_LEFT_MARGIN: The left margin require to align the log without prefix
## LOG_TO_FILE    : [0-1] Set the flag to add the log to a file
## LOG_FILE       : [/path/to/log] The file to use if LOG_TO_FILE is at 1
## LOG_FILE_APPEND: [0-1] Set the flag to append the log to the file or clear the file
## LOG_QUIET      : [0-1] Set the flag to not display the log to stderr (except for the err level log)
## NO_COLOR       : Set to non empty to desactivate the color and style output
##
##   Functions to use the lib
## _loglib_init     : Initialise the library (make sure the flags and global are set before hand)
## _log lvl "msg"   : Message to log with its level of log
## _prompt "msg"    : Prompt th user with the message (use $REPLY)
## _promptpass "msg": Prompt the user with the message, hidden user input (use $REPLY)
## _logline "msg"   : Log a line without prefix
##
##   Log level available
## log: regular log
## sud: sudo log, to log a command will use sudo
## sec: section log, to mark a new section in the script
## war: warning log, to show a warning
## err: error log, to show an error
## suc: success log, to show a success
## fai: fail log, to show a fail
## dry: dry run log, to log the dry run.
## ---------------------------------------

## ---------------------------------------
##   Functions and global variables that should not be used by
## external programs should start with a __ (Double underscore).
## ---------------------------------------

# Avoid lib to be sourced more than once.
[[ "${__LOGLIBLOADED:-""}" == "yes" ]] && return 0
readonly __LOGLIBLOADED="yes"

# If lib is run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

# Get the Lib file path and directory.
readonly __LOGLIB_FILE="$( readlink -f "$BASH_SOURCE" )"
readonly __LOGLIB_DIR="$( dirname "$(readlink -f "${BASH_SOURCE}")" )"

# The left margin needed to align log lines
readonly LOG_LEFT_MARGIN="           "
# Set the log to also wrtie to file set LOG_TO_FILE to 1 to allow it
LOG_TO_FILE=${LOG_TO_FILE-0}
# Set the Log file path, default is inside /var/log/prog.log
LOG_FILE="${LOG_FILE-"/var/log/${_PROG-"prog"}.log"}"
# Set either or not the log will append to the file at init or clear the file
LOG_FILE_APPEND=${LOG_FILE_APPEND-0}
# Set the stderr log to quiet (will only display errors)
LOG_QUIET=${LOG_QUIET-0}
# Non empty to desactivate the color/style output
NO_COLOR=${NO_COLOR-}


# No Colors or style by default (in case the script die before the setup_colors function)
RESET=''
BOLD=''
RED=''              BOLDRED=''              BGRED=''
GREEN=''            BOLDGREEN='' 
YELLOW=''           BOLDYELLOW='' 
BLUE=''             BOLDBLUE=''
PURPLE=''           BOLDPURPLE=''

# log level prefix to append before the log. Will be stylize and colorized
# Style have to be declared inside __get_log_prefix.
#   [key]="6LETTER" => "[6LETTER]  "  
declare -Ar __PREFIX_LEVEL=( 
    [log]="LOG    "
    [sud]="SUDO   "
    [sec]="SECTION"
    [war]="WARNING"
    [err]="ERROR  "
    [suc]="SUCCESS"
    [fai]="FAIL   "
    [dry]="DRYRUN "
    [rea]="PROMPT "
)

## ---------------------------------------
##   Initialize the library
## Usage: loglib_init
## ---------------------------------------
function _loglib_init {
    # Create the file if log to file
    if [[ ${LOG_TO_FILE} = 1 ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
        
        # Clear the file if not appending to it
        [[ ${LOG_FILE_APPEND} = 0 ]] && echo -n "" > "$LOG_FILE"
    fi

    # Setup the colors
    __setup_colors
}

## ---------------------------------------
##   Add a log
## $1: Log Level    Default: err
## $2: Log Message  Default: "No message to log!"
## Usage: _log war "This is my warning"
## ---------------------------------------
function _log {
    local -r lvl="${1-"err"}"
    local -r msg="${2-"No message to log!"}"

    local -r prefix="$(__get_log_prefix ${lvl} )"
    
    # Log to stderr
    if [[ "$lvl" = "err" ]] || [[ ${LOG_QUIET} = 0 ]]; then
        echo >&2 -e "${prefix}${msg}${RESET}"
    fi
    
    # Log to file
    if [[ ${LOG_TO_FILE} = 1 ]]; then
        local -r nocolprefix="$(__get_log_prefix ${lvl} 0 )"
        echo "${nocolprefix}${msg}" >> "${LOG_FILE}"
    fi
}

## ---------------------------------------
##   Prompt the user
## $1: prompt Message  Default: "No prompt!"
## Usage: _prompt "Asking Something: "
##        user_reply="$REPLY"
## ---------------------------------------
function _prompt {
    local -r msg="${1-"No prompt!"}"

    local -r prefix="$(__get_log_prefix rea )"

    echo >&2 -en "${prefix}${msg}${RESET}"
    read
}

## ---------------------------------------
##   Prompt the user (Hide input)
## $1: prompt Message  Default: "No prompt!"
## Usage: _promptpass "Asking Something: "
##        user_reply="$REPLY"
## ---------------------------------------
function _promptpass {
    local -r msg="${1-"No prompt!"}"

    local -r prefix="$(__get_log_prefix rea )"

    echo >&2 -en "${prefix}${msg}${RESET}"
    read -s
    echo ""
}

## ---------------------------------------
##   Add aline without prefix to the log
## $1: Log Message  Default: ""
## Usage: _logline "$LOG_LEFT_MARGIN message"
## ---------------------------------------
function _logline {
    local -r msg="${1-}"
    
    # Log to stderr
    if [[ ${LOG_QUIET} = 0 ]]; then
        echo >&2 -e "${msg}"
    fi
    
    # Log to file
    if [[ ${LOG_TO_FILE} = 1 ]]; then
        echo "${msg}" >> "${LOG_FILE}"
    fi
}


## ---------------------------------------
##   Setup the colors values
## INTERNAL function, shouldn't be used outside of the library
## setup the colors only if the terminal and environement allow it.
## Usage: __setup_colors
## ---------------------------------------
function __setup_colors {
    # https://www.shellhacks.com/bash-colors/
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        RESET='\033[0;0m'
        BOLD='\033[1m'
        RED='\033[0;31m'    BOLDRED='\033[1;31m'    BGRED='\033[1;41m'
        GREEN='\033[0;32m'  BOLDGREEN='\033[1;32m' 
        YELLOW='\033[0;33m' BOLDYELLOW='\033[1;33m' 
        BLUE='\033[0;34m'   BOLDBLUE='\033[1;34m'
        PURPLE='\033[0;35m' BOLDPURPLE='\033[1;35m'
    fi
}

## ---------------------------------------
##   Get the prefix for the log 
## INTERNAL function, shouldn't be used outside of the library
## $1: Log Level        Default: err
## $2: Enable Style     Default: 1
## Usage: newvar="$(__get_log_prefix err 1)"
## ---------------------------------------
function __get_log_prefix {
    local lvl="${1-"err"}"
    local col="${2-1}"

        # Color to apply to the prefix depending on the level.
    declare -A __PREFIX_COLOR=( [log]="${RESET}" [sud]="${BOLDPURPLE}"
        [sec]="${BOLDBLUE}" [war]="${BOLDYELLOW}" [err]="${BOLDRED}"
        [suc]="${BOLDGREEN}" [fai]="${BOLDRED}" [dry]="${BOLD}"
        [rea]="${RESET}"
    )

    # Style to apply to the message after the prefix.
    declare -A __MSG_COLOR=( [log]="${RESET}" [sud]="${RESET}"
        [sec]="${BLUE}" [war]="${YELLOW}" [err]="${BGRED}"
        [suc]="${GREEN}" [fai]="${RED}"  [dry]="${BOLD}"
        [rea]="${RESET}"
    )

    # Get the data
    local -r txtlvl="${__PREFIX_LEVEL[${lvl}]}"
    local -r txtcol="${__PREFIX_COLOR[${lvl}]}"
    local -r msgcol="${__MSG_COLOR[${lvl}]}"

    # Create and return the prefix with the style or not.
    if [[ $col = 0 ]]; then
        echo "[${txtlvl}]  "
    else
        echo "${BOLD}[${txtcol}${txtlvl}${RESET}${BOLD}]  ${msgcol}"
    fi
}
