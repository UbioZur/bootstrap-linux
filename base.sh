#!/usr/bin/env bash

## ---------------------------------------
##  _   _ _     _        ______
## | | | | |   (_)      |___  /
## | | | | |__  _  ___     / / _   _ _ __
## | | | | '_ \| |/ _ \   / / | | | | '__|
## | |_| | |_) | | (_) |./ /__| |_| | |
##  \___/|_.__/|_|\___/ \_____/\__,_|_|
## 
##   UbioZur / ubiozur.tk
##        https://git.ubiozur.tk
##
## ---------------------------------------

## ---------------------------------------
##
## Script name : base.sh
## Description : Linux bootstrap script installing the base system.
## Dependencies: git, openssl, pciutils, tar, loglib.sh, utilslib.sh, envlib.sh
## Repository  : https://github.com/UbioZur/bootstrap-linux
## License     : https://github.com/UbioZur/bootstrap-linux/LICENSE
##
## ---------------------------------------

## ---------------------------------------
##   Fail Fast and cleanup
## E: any trap on ERR is inherited by shell functions, 
##    command substitutions, and commands executed in a subshell environment.
## e: Exit immediately if a pipeline returns a non-zero status.
## u: Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ 
##    as an error when performing parameter expansion
## o pipefail: If set, the return value of a pipeline is the value of the last (rightmost) 
##             command to exit with a non-zero status, or zero if all commands in the
##             pipeline exit successfully.
## ---------------------------------------
set -Eeuo pipefail
# Set the trap to run the cleanup function.
trap cleanup SIGINT SIGTERM ERR EXIT

# Get the script file path and directory.
readonly _SCRIPT_FILE="$( readlink -f "$BASH_SOURCE" )"
readonly _SCRIPT_DIR="$( dirname "$(readlink -f "${BASH_SOURCE}")" )"

# Get the program name
readonly _PROG="$( basename $0 )"

# Source my loglib library if used
source "${_SCRIPT_DIR}/lib/loglib.sh"
# Source my utils library if used
source "${_SCRIPT_DIR}/lib/utilslib.sh"
# Source my env library if used
source "${_SCRIPT_DIR}/lib/envlib.sh"
# Source the commons library between all bootstrap scripts
source "${_SCRIPT_DIR}/lib/common.sh"

# Flag to know if we stop if user is root
ROOT_OK=0
# Flag to not prompt for configurations
NO_PROMPT=1
# URL of the SSH Vault
SSH_VAULT=""
# URL of the GPG Vault
GPG_VAULT=""
# GIT of the dotdiles repo
DOTFILES_REPO=""
# Get the default user (for zsh prompt setting)
DEFAULT_USER=""
# Flag to setup the dotfiles cronjob
DOTFILES_CRON=0
# Set the Grub timeout.
GRUB_TIMEOUT=""
readonly DEFAULT_GRUB_TIMEOUT=5
# Flag to install the RPM Fusion Tainted
RPM_TAINTED=0 
# Flag to not run the cleaning of the $HOME folder
NO_CLEAN_HOME=0
# Flags to install NVidia Drivers (Not the nouveau)
NVIDIA_DRIVERS=0
# Flag to not install docker
NO_DOCKER=0

# Development Flags
DEV_NO_UPGRADE=0
DEV_NO_FUSION=0
DEV_NO_PKGINSTALL=0
DEV_NO_SYSCONFIG=0
DEV_NO_USRCONFIG=0

## ---------------------------------------
##   Script main function
## Usage: main "$@"
## ---------------------------------------
function main {
    # Initialization
    parse_params "$@"
    # Initialize the loglib if it's included!
    _loglib_init

    # Check if user is root or not
    if _is_root; then
        [[ $ROOT_OK = 0 ]] && _die "Script shouldn't be run as root! It will ask for sudo priviledges on the commands that need it!";
        _log war "You are running the script as root!"
    fi

    clear
    _log sec "Preparing the base bootstrap!"
    _create_temp_dir
    _check_pkg_require
    _ensure_ssh_agent
    _log suc "Bootstrap is ready!"
    _logline
    
    _log sec "Distribution Information"
    _display_os_information
    _distro_is_supported
    _logline
    
    _log sec "Hardware Information"
    _display_hdwr_information
    _log suc "Hardware is supported!"
    _prompt_nvidia
    _logline
    
    _log sec "User Information"
    _display_user_information
    if [[ ! _has_sudo ]]; then _die "User need priviledges!" ; fi
    _log suc "User has priviledges!"
    _prompt_default_user
    _logline

    _log sec "Setup Environement!"
    _set_pkgmng
    _set_default_env
    _create_env_folders
    _logline
    sleep 1
    
    _log sec "Setup SSH!"
    _prompt_ssh_vault
    _get_ssh_vault
    _logline

    _log sec "Setup GPG!"
    _prompt_gpg_vault
    _get_gpg_vault
    _logline

    _log sec "Setting up the dotfiles!"
    _prompt_dotfiles_repo
    _get_dotfiles_repo
    _prompt_dotfiles_cron
    _cronjob_dotfiles
    _logline

    _log sec "Setting up Grub Timeout!"
    _prompt_grub_timeout
    _logline

    _log sec "Setting up the Package Manager!"
    _pkgmng_config
    _install_distro_gpg_keys
    _fedora_reset_rpm_fusion
    _pkgman_docker_repo
    _log suc "Package Manager is configured!"
    _logline

    _log sec "Updating the system!"
    _system_update
    _logline

    _log sec "Installing the base Packages!"
    _install_firmware
    _install_nvidia
    _install_pkg
    _install_bin
    _logline

    _log sec "System Configurations!"
    _copy_etc_files
    _copy_fnt_files
    _copy_grub_config
    _logline

    _log sec "User Configurations!"
    _install_dotfiles
    _install_dotfiles_extra
    _install_xdg_config
    _usr_shell_to_zsh
    _clean_home
    _logline

    _log sec "Deployment Finished!"
    _log suc "🖒🖒🖒 System Deployed Successsfully! 🖒🖒🖒"
    _logline

    _log war "You need to reboot the computer!"
    _log log "systemctl reboot"
}

## ---------------------------------------
##   Cleaning up at the script exist (on error or normal)
## Usage: cleanup
## ---------------------------------------
function cleanup {
    trap - SIGINT SIGTERM ERR EXIT

    _cleanup_folders
    _delete_temp_dir
}

## ---------------------------------------
##   Display the usage/help for the script
## Usage: usage
## ---------------------------------------
function usage {
    cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage:  $_PROG [-h]
        $_PROG [-v] [--dry-run] [--no-color] [-q] [-l] [--log-file /path/to/log [--log-append]] [--root-ok]
               [-p] [-s https://url/to/ssh/vault] [-g https://url/to/gpg/vault] [-d git@gitprovider.com:user/dotfiles.git]
               [--cron-dotfiles ] [ -U | -u myuser ] [ -b 5 ] [-t] [-n] [--no-clean-home] [--no-docker]

Bootstrap the installation of a base linux install!

Available options:

    -h, --help          FLAG, Print this help and exit
    -v, --verbose       FLAG, Print script debug info
    --dry-run           FLAG, Display the commands the script will run.
    --root-ok           FLAG, Allow script to be run as root, usefull for container CI.

Log options:

    --no-color          FLAG, Remove style and colors from output.
    -q, --quiet         FLAG, Non error logs are not output to stderr.
    -l, --log-to-file   FLAG, Write the log to a file (Default: /var/log/$_PROG.log).
    --log-file          PARAM, File to write the log to (Also set the --log-to-file flag).
    --log-append        FLAG, Append the log to the file (Also set the --log-to-file flag).

Bootstrap Configurations:

    -p, --prompt        FLAG, Prompt the user for configuration not passed in CLI.
    -s, --ssh-vault     PARAM, The URL of the crypted SSH Vault.
    -g, --gpg-vault     PARAM, The URL of the crypted GPG Vault.
    -d, --dotfiles      PARAM, The URL of the dotfiles git repository.
    --cron-dotfiles     FLAG, Set a cron job to pull the dotfiles (a repo must be set).
    -u, --user          PARAM, Set the default user for the zsh prompt setting.
    -U, --user-me       FLAG, Set the default user to the current user.
    -b, --grub-timeout  PARAM, Time out for GRUB (default is $DEFAULT_GRUB_TIMEOUT).
    -t, --rpm-tainted   FLAG, Install the RPM Fusion Tainted Free.
    -n, --nvidia        FLAG, Install the NVidia Drivers (Not the nouveau ones).
    --no-clean-home     FLAG, Do not clean the \$HOME folder.
    --no-docker         FLAG, Do not install and setup docker.

Development Flags (Designed to used to speedup testing during development!):

    --dev-mode          FLAG, Setup the flags bellow to speed up testing.
    --no-upgrade        FLAG, Do not upgrade the system to speed up testing.
    --no-reset-fusion   FLAG, Do not reset RPM Fusion to speed up testing.
    --no-pkg-install    FLAG, Do not install the packages to speed up testing.
    --no-sys-config     FLAG, Do not copy the system sonfiguration files.
    --no-usr-config     FLAG, Do not set up the configuration for the user.

EOF
    exit
}

## ---------------------------------------
##   Parse the script parameters and set the Flags
## Usage: parse_params "$@"
## ---------------------------------------
function parse_params {
    # default values of variables set from params
    flag=0
    param=''

    while :; do
        case "${1-}" in
            # --------------------------
            #   Common Flags
            # --------------------------
            -h | --help) usage ;;
            -v | --verbose) set -x ;;
            --root-ok) ROOT_OK=1 ;;
            --dry-run) DRY_RUN=1 ;;

            # --------------------------
            #   Log Library flags
            # --------------------------
            --no-color) NO_COLOR=1 ;;
            -q | --quiet) LOG_QUIET=1 ;;
            -l | --log-to-file) LOG_TO_FILE=1 ;;
            --log-file) LOG_TO_FILE=1
                        LOG_FILE="${2-}"
                        shift ;;
            --log-append) LOG_TO_FILE=1
                          LOG_FILE_APPEND=1 ;;

            # --------------------------
            #   Bootstrap Config
            # --------------------------
            -p | --prompt) NO_PROMPT=0 ;;
            -s | --ssh-vault) SSH_VAULT="${2-}"
                              shift
                              ;;
            -g | --gpg-vault) GPG_VAULT="${2-}"
                              shift
                              ;;
            -d | --dotfiles) DOTFILES_REPO="${2-}"
                              shift
                              ;;
            --cron-dotfiles) DOTFILES_CRON=1 ;;
            -u | --user) DEFAULT_USER="${2-}"
                         shift
                         ;;
            -U | --user-me) DEFAULT_USER="$USER" ;;
            -b | --grub_timeout) GRUB_TIMEOUT="${2-}"
                         shift
                         ;;
            -t | --rpm-tainted) RPM_TAINTED=1 ;;
            -n | --nvidia) NVIDIA_DRIVERS=1 ;;
            --no-clean-home) NO_CLEAN_HOME=1 ;;
            --no-docker) NO_DOCKER=1 ;;

            # --------------------------
            #   Development Flags
            # --------------------------
            --dev-mode) DEV_NO_UPGRADE=1
                        DEV_NO_FUSION=1
                        DEV_NO_PKGINSTALL=1
                        DEV_NO_SYSCONFIG=1
                        DEV_NO_USRCONFIG=1
                        ;;
            --no-upgrade) DEV_NO_UPGRADE=1 ;;
            --no-reset-fusion) DEV_NO_FUSION=1 ;;
            --no-pkg-install) DEV_NO_PKGINSTALL=1 ;;
            --no-sys-config) DEV_NO_SYSCONFIG=1 ;;
            --no-usr-config) DEV_NO_USRCONFIG=1 ;;

            -?*) _die "Unknown option: $1" ;;
            *) break ;;
        esac
        shift
    done

    return 0
}

## ---------------------------------------
##   Check we have the require packages
## Usage: _check_pkg_require
## ---------------------------------------
function _check_pkg_require {
    _log log "Checking the required applications are installed."
    declare -ar pkgneeded=( "git" "lspci" "openssl" "ssh-agent" "sudo" "tar" "uname" )
    local hasfailed=0


    for pkg in ${pkgneeded[@]}; do
        if [[ ! $( command -v $pkg ) ]]; then
            _log fai "'$pkg' must be installed!"
            ((hasfailed=hasfailed+1))
        fi
    done
    
    [[ $hasfailed -gt 1 ]] && _die "Missing required applications! Make sure you install them!"
    [[ $hasfailed -eq 1 ]] && _die "Missing required application! Make sure you install it!"
    _log log "Required applications are installed."
}

## ---------------------------------------
##   Prompt user for the NVidia Drivers
## Usage: _prompt_nvidia
## ---------------------------------------
function _prompt_nvidia {
    if ! _gpuis_nvidia ; then return; fi
    [[ $NVIDIA_DRIVERS = 1 ]] && return
    if [[ $NO_PROMPT = 1 ]]; then _log war "Using Nouveau Drivers!" ; return; fi
    
    _log log "Do you want to install NVidia Drivers? Empty to Skip."
    _prompt "NVidia Driver (y/N): "
    case ${REPLY:0:1} in
        y|Y ) NVIDIA_DRIVERS=1 
              _log suc "NVidia drivers will be installed!" ;;
        * ) NVIDIA_DRIVERS=0
            _log log "NVidia drivers will NOT be installed!" ;;
    esac
}

## ---------------------------------------
##   Prompt for the default user
## Usage: _prompt_default_user
## ---------------------------------------
function _prompt_default_user {
    [[ $NO_PROMPT = 1 || ! -z "$DEFAULT_USER" ]] && return
    _log log "What is the default user for the cli prompt? Empty Value to skip."
    _prompt "Default User: "
    DEFAULT_USER="$REPLY"
}

## ---------------------------------------
##   Setup Env Variables to defaults
## Usage: _set_default_env
## ---------------------------------------
function _set_default_env {
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME-"$HOME/.config"}"
    XDG_PROJECTS_DIR="${XDG_PROJECTS_DIR-"$HOME/Projects"}"
    XDG_DATA_HOME="${XDG_DATA_HOME-"$HOME/.local/share"}"
    SSHHOME="${SSHHOME-"$XDG_DATA_HOME/ssh"}"
    GNUPGHOME="${GNUPGHOME="$XDG_DATA_HOME/gnupg"}"

    DOTFILES_PROJ="$XDG_PROJECTS_DIR/dotfiles"

    _log log "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME}"
    _log log "XDG_PROJECTS_DIR: ${XDG_PROJECTS_DIR}"
    _log log "XDG_DATA_HOME: ${XDG_DATA_HOME}"
    _log log "SSHHOME: ${SSHHOME}"
    _log log "GNUPGHOME: ${GNUPGHOME}"
    _log log "DOTFILES_PROJ: ${DOTFILES_PROJ}"

    _log log "Package Manager Command: $_PKG_MNG"
}

## ---------------------------------------
##   Create folders from the environment variables
## Usage: _create_env_folders
## ---------------------------------------
function _create_env_folders {
    _create_folder "${XDG_CONFIG_HOME}"
    _create_folder "${XDG_PROJECTS_DIR}"
    _create_folder "${XDG_DATA_HOME}"
    _create_folder "${SSHHOME}"
    _create_folder "${GNUPGHOME}"
}

## ---------------------------------------
##   Prompt user for the SSH Vault
## Usage: _prompt_ssh_vault
## ---------------------------------------
function _prompt_ssh_vault {
    [[ $NO_PROMPT = 1 || ! -z "$SSH_VAULT" ]] && return
    
    _log log "Where is the archive of your ssh vault? Empty Value to skip."
    _prompt "SSH Vault URL: "
    SSH_VAULT="$REPLY"
}

## ---------------------------------------
##   uncompress and set the SSH Vault
## Usage: _get_ssh_vault
## ---------------------------------------
function _get_ssh_vault {
    if [[ -z "$SSH_VAULT" ]]; then _log war "SSH setup is skipped!" ; return; fi
    
    _log log "Downloading SSH Vault from: '$SSH_VAULT'"
    local -r ssh_archive="$_TMP_DIR/ssh.tar.gz"
    
    # Download the vault
    local -r download_cmd="curl -L --fail ${SSH_VAULT} -o ${ssh_archive}"
    _run "$download_cmd"
    [[ ${?} = 0 ]] ||  _die "Failed to download '$SSH_VAULT'!"
    
    # Decrypt the vault
    _log log "Decoding SSH Vault..."
    local -r decode_cmd="openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -in $ssh_archive"
    local -r tar_cmd="tar xz -C $SSHHOME"
    
    # Special case for DRY_RUN as the pipe doesn't work with openssl in the _run if not in dry run!
    if [[ $DRY_RUN = 1 ]]; then
        _run "$decode_cmd | $tar_cmd"
        _run "export GIT_SSH_COMMAND=\"/usr/bin/ssh -F $SSHHOME/config\""
    else
        $decode_cmd | tar xz -C $SSHHOME || _die "An Error occured while decoding the SSH Vault!"
        export GIT_SSH_COMMAND="/usr/bin/ssh -F $SSHHOME/config"
    fi

    _run "sudo chown -R $USER:$USER $SSHHOME"
    _run "sudo chmod -R 700 $SSHHOME"

    _log suc "SSH is now setup."
}

## ---------------------------------------
##   Prompt user for the GPG Vault
## Usage: _prompt_gpg_vault
## ---------------------------------------
function _prompt_gpg_vault {
    [[ $NO_PROMPT = 1 || ! -z "$GPG_VAULT" ]] && return
    
    _log log "Where is the archive of your gpg vault? Empty Value to skip."
    _prompt "GPG Vault URL: "
    GPG_VAULT="$REPLY"
}

## ---------------------------------------
##   uncompress and set the GPG Vault
## Usage: _get_gpg_vault
## ---------------------------------------
function _get_gpg_vault {
    if [[ -z "$GPG_VAULT" ]]; then _log war "GPG setup is skipped!" ; return; fi
    
    _log log "Downloading GPG Vault from: '$GPG_VAULT'"
    local -r gpg_archive="$_TMP_DIR/gpg.tar.gz"
    
    # Download the vault
    local -r download_cmd="curl -L --fail ${GPG_VAULT} -o ${gpg_archive}"
    _run "$download_cmd"
    [[ ${?} = 0 ]] ||  _die "Failed to download '$GPG_VAULT'!"
    
    # Decrypt the vault
    _log log "Decoding GPG Vault..."
    local -r decode_cmd="openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -in $gpg_archive"
    local -r tar_cmd="tar xz -C $GNUPGHOME"
    
    # Special case for DRY_RUN as the pipe doesn't work with openssl in the _run if not in dry run!
    if [[ $DRY_RUN = 1 ]]; then
        _run "$decode_cmd | $tar_cmd"
    else
        $decode_cmd | tar xz -C $GNUPGHOME || _die "An Error occured while decoding the GPG Vault!"
    fi

    _run "sudo chown -R $USER:$USER $GNUPGHOME"
    _run "sudo chmod -R 700 $GNUPGHOME"

    _log suc "GPG is now setup."
}

## ---------------------------------------
##   Prompt user for the Dotfiles Repo
## Usage: _prompt_dotfiles_repo
## ---------------------------------------
function _prompt_dotfiles_repo {
    [[ $NO_PROMPT = 1 || ! -z "$DOTFILES_REPO" ]] && return
    
    _log log "Where is the git for your dotfiles? Empty Value to skip."
    _prompt "Dotfiles git URL: "
    DOTFILES_REPO="$REPLY"
}

## ---------------------------------------
##   download the dotfiles repo
## Usage: _get_dotfiles_repo
## ---------------------------------------
function _get_dotfiles_repo {
    if [[ -z "$DOTFILES_REPO" ]]; then _log war "Dotfiles setup is skipped!" ; return; fi

    _create_folder "${DOTFILES_PROJ}"

    _get_git_repo "${DOTFILES_REPO}" "${DOTFILES_PROJ}"
}

## ---------------------------------------
##   Prompt user for the Dotfiles Repo cronjob
## Usage: _prompt_dotfiles_cron
## ---------------------------------------
function _prompt_dotfiles_cron {
    [[ $NO_PROMPT = 1 || -z "$DOTFILES_REPO" || $DOTFILES_CRON = 1 ]] && return
    
    _log log "Do you want to set a cron job to pull the dotfiles repo daily? 'y' for yes."
    _prompt "Set Dotfiles cron (y/N) ?"
    case ${REPLY:0:1} in
        y|Y ) DOTFILES_CRON=1 ;;
        * ) DOTFILES_CRON=0 ;;
    esac
}

## ---------------------------------------
##   Set dotfiles pull cronjob.
## Mostly for systems where the dotfiles are not edited.
## Usage: _cronjob_dotfiles
## ---------------------------------------
function _cronjob_dotfiles {
    [[ -z "$DOTFILES_REPO" || $DOTFILES_CRON = 0 ]] && return
    
    # Create a daily git pull that is quiet, will stash change, rebase the remote, and put change again.
    local -r cron_command="/usr/bin/git -C "$DOTFILES_PROJ" pull -q --rebase --autostash  > /dev/null"
    local -r cron_job="@daily $cron_command"

    # For dry-run and easier reading, cronjob will be temporary saved into a file
    local -r cron_file="$_TMP_DIR/cronjobs"
    _crontab_list | _my_grep -v -F "$cron_command" ; echo "$cron_job" > "$cron_file"
    [[ $DRY_RUN = 1 ]] && _log dry "$( _multiline_log "Cronjobs:" "$( cat "$cron_file" )" )"
    _run "crontab $cron_file"

    _log suc "Daily cron job added to pull the dotfiles repository!"
}

## ---------------------------------------
##   Prompt user for the Grub Timeout
## Usage: _prompt_grub_timeout
## ---------------------------------------
function _prompt_grub_timeout {
    if [[ $NO_PROMPT = 1 ]]; then _log war "Grub Timeout setup is skipped!" ; return; fi
    if [[ ! -z "$GRUB_TIMEOUT" ]]; then _log suc "Grub Timeout will be set to: ${GRUB_TIMEOUT}s!" ; return; fi
    
    _log log "What is the grub timeout you would like? (Default: $DEFAULT_GRUB_TIMEOUT)."
    _prompt "Grub Timeout: "
    local -r isnumber='^[0-9]+$'
    if [[ -z "${REPLY-}" ]]; then
        _log war "Grub Timeout setting skipped."
        GRUB_TIMEOUT=$DEFAULT_GRUB_TIMEOUT
        return
    fi
    if [[ ! "$REPLY" =~ $isnumber ]] ; then
        _log fai "'$REPLY' is not a number, setting value to default: $DEFAULT_GRUB_TIMEOUT"
        GRUB_TIMEOUT=$DEFAULT_GRUB_TIMEOUT
        return
    fi
    GRUB_TIMEOUT=$REPLY
    _log suc "Grub Timeout will be set to: ${GRUB_TIMEOUT}s!"
}


## ---------------------------------------
##   Setup the config manager config file
## Usage: _pkgmng_config
## ---------------------------------------
function _pkgmng_config {
    if _is_fedora; then __pkgmng_config_dnf ; return; fi

    _log fai "Something is wrong with _pkgmng_config!"
}

## ---------------------------------------
##   Setup the config manager config file for DNF
## Usage: __pkgmng_config_dnf
## ---------------------------------------
function __pkgmng_config_dnf {
    local -r cfg_file="/etc/dnf/dnf.conf"
    local -r cfg_repo="${_SCRIPT_DIR}/files${cfg_file}"
    _log sud "Copying DNF config file to '$cfg_file'"
    
    _copy_as_root "$cfg_repo" "$cfg_file"
}

## ---------------------------------------
##   Install the Distribution GPG keys
## Usage: _install_distro_gpg_keys
## ---------------------------------------
function _install_distro_gpg_keys {
    local -r fedora_pkg="distribution-gpg-keys dnf-plugins-core"

    _log sud "Installing the Distribution GPG Keys"
    if _is_fedora; then _run "$_PKG_MNG -q install $fedora_pkg" ; return; fi

    _log fai "Something is wrong with _install_distro_gpg_keys!"
}

## ---------------------------------------
##   Reset/Install the RPM Fusion (Fedora Only)
## Usage: _fedora_reset_rpm_fusion
## ---------------------------------------
function _fedora_reset_rpm_fusion {
    if ! _is_fedora; then return; fi

    _log sud "Resetting / Installing RPM Fusion"

    #If not in Dry run and we have the no fusion set for development, then skip
    [[ $DEV_NO_FUSION = 1 ]] && return

    # Set the tainted variable depending on the Flag.
    local tainted=""
    [[ $RPM_TAINTED = 1 ]] && tainted="rpmfusion-free-release-tainted"
    # List of packages to install
    local -r pkglst="https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                     https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
                     ${tainted-}"
    # Remove previous rpm fusion packages (to make sure it will reset to the current fedora release)
    _run "$_PKG_MNG -q remove rpmfusion-free-release rpmfusion-nonfree-release rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted"
    # Install the packages
    _run "$_PKG_MNG -q install $pkglst"
}

## ---------------------------------------
##   Setup the package manager docker repository
## Usage: _pkgman_docker_repo
## ---------------------------------------
function _pkgman_docker_repo {
    [[ $NO_DOCKER = 1 ]] && return
    _log sud "Adding Docker Repository"

    if _is_fedora; then _dnf_add_docker_repo ; return; fi

    _log fai "Something is wrong with _pkgman_docker_repo!"
}

## ---------------------------------------
##   Setup DNF docker repository
## Usage: _dnf_add_docker_repo
## ---------------------------------------
function _dnf_add_docker_repo {
    local -r reponame="docker-ce-stable"

    # if repo is enabled, do nothing
    if _dnfrepo_is_enabled "$reponame"; then
        _log suc "$reponame is already enabled!"
        return
    fi

    # if repo is diabled, enable it
    if _dnfrepo_is_disabled "$reponame"; then
        _run "$_PKG_MNG repolist --enablerepo $reponame 1> /dev/null"
        _log suc "$reponame is now enabled!"
        return
    fi

    # add the repo. https://docs.docker.com/engine/install/fedora/
    _run "$_PKG_MNG config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"

    _log suc "$reponame is now added!"
}

## ---------------------------------------
##   Update the system.
## Usage: _system_update
## ---------------------------------------
function _system_update {
    _log sud "Upgrading the system"
    
    [[ $DEV_NO_UPGRADE = 1 ]] && return
    
    if _is_fedora; then
        _run "$_PKG_MNG clean all"
        _run "$_PKG_MNG upgrade --best --allowerasing --refresh"
        _run "$_PKG_MNG distro-sync"
        return
    fi

    _log fai "Something is wrong with _system_update!"
}


## ---------------------------------------
##   Installing the system firmware
## Usage: _install_firmware
## ---------------------------------------
function _install_firmware {
    _log sud "Installing microcodes"
    
    [[ $DEV_NO_PKGINSTALL = 1 ]] && return

    if _is_fedora; then _run "$_PKG_MNG -q install microcode_ctl" ; return; fi
    
    _log fai "Something is wrong with _install_firmware!"
}

## ---------------------------------------
##   Installing the nvidia drivers
## Usage: _install_nvidia
## ---------------------------------------
function _install_nvidia {
    [[ NVIDIA_DRIVERS = 0 ]] && return
    
    _log sud "Installing NVidia drivers"
    
    if _is_fedora; then _run "$_PKG_MNG -q install akmod-nvidia" ; return; fi

    _log fai "Something is wrong with _install_nvidia!"
}

## ---------------------------------------
##   Installing the base packages
## Usage: _install_pkg
## ---------------------------------------
function _install_pkg {
    _log sud "Installing packages"
    
    [[ $DEV_NO_PKGINSTALL = 1 ]] && return

    if _is_fedora; then
        local -r pkglist_file="$_SCRIPT_DIR/Fedora/base.conf";
        local pkglist=""
        if [[ ! -f $pkglist_file ]]; then 
            _log fai "File \"$pkglist_file\" does not exist to know what packages to install!"
        else
            pkglist="$(cat $pkglist_file | tr '\n' ' ')"
        fi

        [[ $NO_DOCKER = 0 ]] && pkglist="${pkglist} docker-ce docker-ce-cli docker-compose-plugin"

        # Installing the Core Group.
        _run "$_PKG_MNG -q install @Core $pkglist"

        return
    fi
    
    _log fai "Something is wrong with _install_pkg!"
}

## ---------------------------------------
##   Installing repo bin packages
## Usage: _install_bin
## ---------------------------------------
function _install_bin {
    _log sud "Installing bin files from repo"

    [[ $DEV_NO_PKGINSTALL = 1 ]] && return

    # PFetch.
    local -r pfetch="/usr/bin/pfetch"
    local -r pfetch_repo="${_SCRIPT_DIR}/files${pfetch}"
    _copy_as_root "$pfetch_repo" "$pfetch" 755

    # VaultCrypt.
    local -r vcrypt="/usr/bin/vault-crypt"
    local -r vcrypt_repo="${_SCRIPT_DIR}/files${vcrypt}"
    _copy_as_root "$vcrypt_repo" "$vcrypt" 755
}

## ---------------------------------------
##   Copying the config files from the /etc folder.
## Usage: _copy_etc_files
## ---------------------------------------
function _copy_etc_files {
    _log sud "Copying /etc/... configuration files"

    [[ $DEV_NO_SYSCONFIG = 1 ]] && return
    local -r repoetcdir="${_SCRIPT_DIR}/files/etc"
    _copy_as_root "${repoetcdir}/issue" "/etc/issue"
    _copy_as_root "${repoetcdir}/issue.net" "/etc/issue.net"
    _copy_as_root "${repoetcdir}/motd" "/etc/motd"
    _copy_as_root "${repoetcdir}/zshenv" "/etc/zshenv"
    _copy_as_root "${repoetcdir}/ssh/ssh_config.d/99-SSH-away-from-home.conf" "/etc/ssh/ssh_config.d/99-SSH-away-from-home.conf"
}

## ---------------------------------------
##   Copying the config files from the /usr folder.
## Usage: _copy_fnt_files
## ---------------------------------------
function _copy_fnt_files {
    _log sud "Copying fonts files"

    [[ $DEV_NO_SYSCONFIG = 1 ]] && return
    local -r repousrdir="${_SCRIPT_DIR}/files/usr"
    _copy_as_root "${repousrdir}/share/fonts/google-droid-sans-mono-fonts/DroidSansMonoNerdFont.otf" \
                  "/usr/share/fonts/google-droid-sans-mono-fonts/DroidSansMonoNerdFont.otf"

    _run "sudo fc-cache -f"
}

## ---------------------------------------
##   Setting up GRUB.
## Usage: _copy_grub_config
## ---------------------------------------
function _copy_grub_config {
    _log sud "Copying GRUB config"

    [[ $DEV_NO_SYSCONFIG = 1 ]] && return
    local -r conf="/etc/default/grub"
    local -r tmpconf="${_TMP_DIR}/grub"
    # Create file from template to TMP folder (can't create from template with sudo)
    touch "$tmpconf"
    _template "${_SCRIPT_DIR}/templates${conf}" > "$tmpconf"

    # Copy file from TMP to it's dir.
    _copy_as_root "$tmpconf" "$conf"

    # Generate Grub config
    if _is_fedora; then _run "sudo grub2-mkconfig -o /etc/grub2-efi.cfg" ; return; fi

    _log fai "Something is wrong with _copy_grub_config!"
}

## ---------------------------------------
##   Install the dotfiles from the repo 
## Usage: _install_dotfiles
## ---------------------------------------
function _install_dotfiles {
    _log log "Installing dotfiles"

    [[ $DEV_NO_USRCONFIG = 1 ]] && return
    local -r df_inst="$DOTFILES_PROJ/install.sh"

    # If there is no install script (possibly due to dry run mode not actually downloading the repo), skip the install.
    if [[ ! -f "$df_inst" ]]; then 
        if [[ $DRY_RUN = 1 ]]; then _log war "Dotfiles install skipped (no install script possibly due to the dry run)!" ; return; fi
        _log war "Dotfiles install skipped (no install script)!"
        return
    fi

    # Run the install script.
    if [[ $DRY_RUN = 1 ]]; then
        _run "$df_inst"
        $df_inst --dry-run
        return
    fi
    
    $df_inst
}

## ---------------------------------------
##   Tweak dotfiles 
## Usage: _install_dotfiles_extra
## ---------------------------------------
function _install_dotfiles_extra {
    _log log "Generate extra dotfiles"

    [[ $DEV_NO_USRCONFIG = 1 ]] && return
    local -r conf="$XDG_CONFIG_HOME/shell/sysenv"
    local -r tmpconf="$_TMP_DIR/sysenv"
    local -r templates="${_SCRIPT_DIR}/templates/config/shell/sysenv.tmpl"

    # Create from the template to the tmp folder
    touch "$tmpconf"
    _template "$templates" > "$tmpconf"

    #Copy from tmp to destination.
    _run "cp -f "$tmpconf" "$conf""
}

## ---------------------------------------
##   Install XDG Configs 
## Usage: _install_xdg_config
## ---------------------------------------
function _install_xdg_config {
    _log log "Installing xdg config files"

    [[ $DEV_NO_USRCONFIG = 1 ]] && return
    local -r repoconfigdir="${_SCRIPT_DIR}/files/config"
    _run "cp -f "$repoconfigdir/user-dirs.dirs" "$XDG_CONFIG_HOME/user-dirs.dirs""
    _run "cp -f "$repoconfigdir/user-dirs.locale" "$XDG_CONFIG_HOME/user-dirs.locale""
}


## ---------------------------------------
##   Set the user shell to zsh 
## Usage: _usr_shell_to_zsh
## ---------------------------------------
function _usr_shell_to_zsh {
    if [[ ! -x /bin/zsh ]]; then _log fai "ZSH is not installed, cannot set user shell to ZSH!" ; return; fi
    _run "sudo usermod --shell /bin/zsh $USER"
}

## ---------------------------------------
##   Clean the home folder 
## Usage: _clean_home
## ---------------------------------------
function _clean_home {
    if [[ $NO_CLEAN_HOME = 1 ]]; then _log war "Skipping cleaning home folder '$HOME'!" ; return; fi
    _log log "Cleaning the home folder"
    
    # Removing the .ssh folder as it should be in $HOME/.local/share/ssh
    _run "rm -Rf $HOME/.ssh"
    # Using zsh, so cleaning .bash files (may still have a .bash_history after reboot/relog)
    _run "rm -f $HOME/.bash*"
    # Less history is moved by dotfiles to $HOME/.local/state/less/history
    _run "rm -f $HOME/.lesshst"
}

main "$@"; exit