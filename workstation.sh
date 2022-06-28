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
## Script name : workstation.sh
## Description : Linux bootstrap script setting up my workstation (after the base.sh script).
## Dependencies: git, pciutils, loglib.sh, utilslib.sh, envlib.sh
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
# Flag to install the NVidia Drivers and Utils
NVIDIA_DRIVERS=0
# Templates Repository
TEMPLATES_REPO=""

# Development flags
DEV_NO_EXT_REPOS=0
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
    _logline

    _log sec "Setup Environement!"
    _set_pkgmng
    _set_default_env
    _create_env_folders
    _logline
    sleep 1

    _log sec "Bootstrap Configuration"
    _prompt_templates_repo
    _get_templates_repo
    _logline

    _log sec "Package Manager configuration"
    _repo_codium
    _repo_brave
    _repo_joplin
    _logline
    
    _log sec "Installing the workstations packages"
    _install_pkg
    _install_dracula_theme
    _install_gromitmpx
    _logline

    _log sec "System Configurations!"
    _copy_etc_files
    _setup_flathub
    _logline

    _log sec "User Configurations!"
    _install_dotfiles
    _install_templates
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
               [-p] [-n] [-t git@gitprovider.com:user/templates.git]

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
    -n, --nvidia        FLAG, Install the NVidia Drivers (Not the nouveau ones).
    -t, --templates     PARAM, Repository for the Template folders.

Development Flags (Designed to used to speedup testing during development!):

    --dev-mode          FLAG, Setup the flags bellow to speed up testing.
    --no-ext-repos      FLAG, Do not add external repositories to speed up testing.
    --no-pkg-install    FLAG, Do not install packages to speed up testing.
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
            -n | --nvidia) NVIDIA_DRIVERS=1 ;;
            -t | --templates) TEMPLATES_REPO="${2-}"
                              shift ;;

            # --------------------------
            #   Development Flags
            # --------------------------
            --dev-mode) DEV_NO_EXT_REPOS=1
                        DEV_NO_PKGINSTALL=1
                        DEV_NO_SYSCONFIG=1 ;;
            --no-ext-repos) DEV_NO_EXT_REPOS=1 ;;
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
    declare -ar pkgneeded=( "git" "lspci" "ssh-agent" "sudo" "tar" "uname" )
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
    
    _log log "Do you want to install NVidia Drivers and utils? (Empty to Skip)."
    _prompt "NVidia Drivers (y/N): "
    case ${REPLY:0:1} in
        y|Y ) NVIDIA_DRIVERS=1 
              _log suc "NVidia drivers and utils will be installed!" ;;
        * ) NVIDIA_DRIVERS=0
            _log log "NVidia drivers and utils will NOT be installed!" ;;
    esac
}

## ---------------------------------------
##   Setup Env Variables to defaults
## Usage: _set_default_env
## ---------------------------------------
function _set_default_env {
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME-"$HOME/.config"}"
    XDG_DATA_HOME="${XDG_DATA_HOME-"$HOME/.local/share"}"
    XDG_BIN_HOME="${XDG_BIN_HOME-"$HOME/.local/bin"}"
    XDG_PROJECTS_DIR="${XDG_PROJECTS_DIR-"$HOME/Projects"}"
    XDG_PICTURES_DIR="${XDG_PICTURES_DIR-"$HOME/Pictures"}"
    XDG_TEMPLATES_DIR="${XDG_TEMPLATES_DIR-"$HOME/Templates"}"
    SSHHOME="${SSHHOME-"$XDG_DATA_HOME/ssh"}"
    GNUPGHOME="${GNUPGHOME="$XDG_DATA_HOME/gnupg"}"

    DOTFILES_PROJ="$XDG_PROJECTS_DIR/dotfiles"
    TEMPLATES_PROJ="$XDG_PROJECTS_DIR/templates"

    _log log "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME}"
    _log log "XDG_DATA_HOME: ${XDG_DATA_HOME}"
    _log log "XDG_BIN_HOME: ${XDG_BIN_HOME}"
    _log log "XDG_PROJECTS_DIR: ${XDG_PROJECTS_DIR}"
    _log log "XDG_PICTURES_DIR: ${XDG_PICTURES_DIR}"
    _log log "XDG_TEMPLATES_DIR: ${XDG_TEMPLATES_DIR}"
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
    _create_folder "${XDG_DATA_HOME}"
    _create_folder "${XDG_BIN_HOME}"
    _create_folder "${XDG_PROJECTS_DIR}"
    _create_folder "${XDG_PICTURES_DIR}"
    _create_folder "${XDG_TEMPLATES_DIR}"
    _create_folder "${SSHHOME}"
    _create_folder "${GNUPGHOME}"
}


## ---------------------------------------
##   Prompt user for the Templates Repo
## Usage: _prompt_templates_repo
## ---------------------------------------
function _prompt_templates_repo {
    [[ $NO_PROMPT = 1 || ! -z "$TEMPLATES_REPO" ]] && return
    
    _log log "Where is the git for your templates? Empty Value to skip."
    _prompt "Templates git URL: "
    TEMPLATES_REPO="$REPLY"
}

## ---------------------------------------
##   download the templates repo
## Usage: _get_templates_repo
## ---------------------------------------
function _get_templates_repo {
    if [[ -z "$TEMPLATES_REPO" ]]; then _log war "Templates setup is skipped!" ; return; fi

    _create_folder "${TEMPLATES_PROJ}"
    
    _get_git_repo "${TEMPLATES_REPO}" "${TEMPLATES_PROJ}"
}


## ---------------------------------------
##   Add the repository for VSCodium
## Usage: _repo_codium
## ---------------------------------------
function _repo_codium {
    _log sud "Adding VSCodium Repository"

    [[ $DEV_NO_EXT_REPOS = 1 ]] && return

    if _is_fedora; then _dnf_add_codium_repo; return; fi

    _log fai "Something is wrong with _repo_codium!"
}

## ---------------------------------------
##   Add the repository for VSCodium for DNF
## Usage: _dnf_add_codium_repo
## ---------------------------------------
function _dnf_add_codium_repo {
    local -r reponame="gitlab.com_paulcarroty_vscodium_repo"

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

    # Add the repo. https://vscodium.com/#install
    _run "sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg"
    local -r codium_string="[$reponame]\nname=Codium Repository\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg\nmetadata_expire=1h"
    printf "$codium_string" | tee "$_TMP_DIR/codium.repo" 1> /dev/null
    _copy_as_root "$_TMP_DIR/codium.repo" "/etc/yum.repos.d/codium.repo"
    
    _log suc "$reponame is now added!"
}

## ---------------------------------------
##   Add the repository for Brave-Browser
## Usage: _repo_brave
## ---------------------------------------
function _repo_brave {
    _log sud "Adding VSCodium Repository"

    [[ $DEV_NO_EXT_REPOS = 1 ]] && return

    if _is_fedora; then _dnf_add_brave_repo; return; fi

    _log fai "Something is wrong with _repo_brave!"
}

## ---------------------------------------
##   Add the repository for Brave-Browser for DNF
## Usage: _dnf_add_brave_repo
## ---------------------------------------
function _dnf_add_brave_repo {
    local -r reponame="brave-browser-rpm-release.s3.brave.com_x86_64_"

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

    # Add the repo. https://brave.com/linux/
    _run "$_PKG_MNG config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/"
    _run "sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"

    _log suc "$reponame is now added!"
}

## ---------------------------------------
##   Add the repository for Joplin
## Usage: _repo_joplin
## ---------------------------------------
function _repo_joplin {
    _log sud "Adding Joplin Repository"

    [[ $DEV_NO_EXT_REPOS = 1 ]] && return

    if _is_fedora; then _copr_add_joplin; return; fi

    _log fai "Something is wrong with _repo_joplin!"
}

## ---------------------------------------
##   Add the Joplin Copr
## Usage: _copr_add_joplin
## ---------------------------------------
function _copr_add_joplin {
    _run "$_PKG_MNG copr enable taw/joplin"

    _log suc "Copr added: 'taw/joplin'"
}


## ---------------------------------------
##   Installing the workstation packages
## Usage: _install_pkg
## ---------------------------------------
function _install_pkg {
    _log sud "Installing packages"
    
    [[ $DEV_NO_PKGINSTALL = 1 ]] && return

    local pkglist=""
    
    if _is_fedora; then
        if [[ $DRY_RUN = 1 ]]; then
            _run "$_PKG_MNG -q install @\"Administration tools\" @base-x @Fonts @\"Hardware Support\" @\"Input Methods\" @Multimedia"
        else
            $_PKG_MNG install @"Administration tools" @base-x @Fonts @"Hardware Support" @"Input Methods" @Multimedia
        fi
        pkglist="$( _get_pkglist_fedora ) $( _get_pkglist_nvidia )"
    fi

    if [[ $DRY_RUN = 1 ]]; then
        _run "$_PKG_MNG install $pkglist"
    else
        $_PKG_MNG install $pkglist
    fi

    _log suc "Workstation Packages installed!"
}

## ---------------------------------------
##   Return the list of packages to install for nvidia
## Usage: local pkglst="$( _get_pkglist_nvidia )"
## ---------------------------------------
function _get_pkglist_nvidia {
    [[ $NVIDIA_DRIVERS = 0 ]] && return

    echo "akmod-nvidia nvidia-xconfig xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-power"
}

## ---------------------------------------
##   Return the list of pkg to install for fedora
## Usage: local pkglst="$( _get_pkglist_fedora )"
## ---------------------------------------
function _get_pkglist_fedora {
    local -r pkglist_file="$_SCRIPT_DIR/Fedora/workstation.conf";
        
    if [[ ! -f $pkglist_file ]]; then 
        _log fai "File \"$pkglist_file\" does not exist to know what packages to install!"
        echo ""
        return
    fi
    
    echo "$(cat $pkglist_file | tr '\n' ' ')"
}

## ---------------------------------------
##   Download and install the dracula Theme
## Usage: _install_dracula_theme
## ---------------------------------------
function _install_dracula_theme {
    _log sud "Installing Dracula Theme"
    [[ $DEV_NO_PKGINSTALL = 1 ]] && return

    local -r themesdir="/usr/share/themes"
    local -r iconsdir="/usr/share/icons"
    # Latest GTK Dracula Theme release
    local -r themeurl="https://github.com/dracula/gtk/releases/latest/download/Dracula.tar.xz"
    # Latest GTK Dracula Cursor Theme release
    local -r cursorurl="https://github.com/dracula/gtk/releases/latest/download/Dracula-cursors.tar.xz"
    # Icons themes that can match Dracula theme
    local -r iconsgit="https://github.com/vinceliuice/Tela-circle-icon-theme.git"

    # Download the theme files.
    local -r dwdir="$_TMP_DIR/themes"
    _create_folder "$dwdir/icons" "$dwdir/theme" "$dwdir/cursor"
    _run "wget -q -P "$dwdir" "$themeurl""
    _run "wget -q -P "$dwdir" "$cursorurl""
    _run "git clone -q "$iconsgit" "$dwdir/icons""

    # Uncompress the theme and cursor.
    _run "tar -xJf "$dwdir/Dracula.tar.xz" -C "$dwdir/theme""
    _run "tar -xJf "$dwdir/Dracula-cursors.tar.xz" -C "$dwdir/cursor""

    # Copying the theme to the system.
    _run "sudo rsync --chown root:root --info=progress2 -aq "$dwdir/theme/" "$themesdir""
    _run "sudo rsync --chown root:root --info=progress2 -aq "$dwdir/cursor/" "$iconsdir""
    _run "sudo $dwdir/icons/install.sh dracula"
}

## ---------------------------------------
##   Download and install gromit-mpx application 
## Usage: _install_gromitmpx
## ---------------------------------------
function _install_gromitmpx {
    _log sud "Installing Gromit MPX from repo"
    [[ $DEV_NO_PKGINSTALL = 1 ]] && return
    
    local -r gromit_tmp="$_TMP_DIR/gromit-mpx"
    _create_folder "$gromit_tmp"
    
    # Grabbing Gromit Repository
    _run "git init --initial-branch=master "$gromit_tmp""
    _run "git -C "$gromit_tmp" remote add origin "https://github.com/bk138/gromit-mpx.git""
    _run "git -C "$gromit_tmp" fetch --depth=20"
    _run "git -C "$gromit_tmp" checkout -f master"
    _run "git -C "$gromit_tmp" pull"
    
    # Building Gromit-MPX
    local -r oldpwd="$(pwd)"
    _create_folder "$gromit_tmp/build" && cd "$gromit_tmp/build"
    _run "cmake --log-level=ERROR .."
    _run "make --quiet"
    
    # Install Gromit-MPX
    _run "sudo make install"
}


## ---------------------------------------
##   Copying the config files from the /etc folder.
## Usage: _copy_etc_files
## ---------------------------------------
function _copy_etc_files {
    _log sud "Copying /etc/... configuration files"

    [[ $DEV_NO_SYSCONFIG = 1 ]] && return
    local -r repoetcdir="${_SCRIPT_DIR}/files/etc"
    _copy_as_root "${repoetcdir}/issue.workstation" "/etc/issue"
}

## ---------------------------------------
##   Setup Flathub if flatpak is installed.
## Usage: _setup_flathub
## ---------------------------------------
function _setup_flathub {
    if [[ ! -x "$( which flatpak )" ]]; then _log war "Flatpak is not installed. Skipping setting up flathub!" ; return; fi
    _log sud "Adding Flathub to Flatpak"

    [[ $DEV_NO_SYSCONFIG = 1 ]] && return

    # Only add if it's not only in it, to avoid a 'useless' password prompt.
    if [[ $( flatpak remotes | _my_grep flathub | wc -l ) = 0 ]]; then
        _run "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    fi
}


## ---------------------------------------
##   Install the dotfiles from the repo 
## Usage: _install_dotfiles
## ---------------------------------------
function _install_dotfiles {
    _log log "Installing dotfiles"

    [[ $DEV_NO_USRCONFIG = 1 ]] && return
    local df_inst="$DOTFILES_PROJ/install.sh"

    # If there is no install script (possibly due to dry run mode not actually downloading the repo), skip the install.
    if [[ ! -f "$df_inst" ]]; then 
        if [[ $DRY_RUN = 1 ]]; then _log war "Dotfiles install skipped (no install script possibly due to the dry run)!" ; return; fi
        _log war "Dotfiles install skipped (no install script)!"
        return
    fi

    df_inst="$df_inst -a"

    # Run the install script.
    if [[ $DRY_RUN = 1 ]]; then
        _run "$df_inst"
        $df_inst --dry-run
        return
    fi
    
    $df_inst
}

## ---------------------------------------
##   Install the templates from the repo 
## Usage: _install_templates
## ---------------------------------------
function _install_templates {
    _log log "Installing templates"

    [[ $DEV_NO_USRCONFIG = 1 ]] && return
    local inst="$TEMPLATES_PROJ/install.sh"

    # If there is no install script (possibly due to dry run mode not actually downloading the repo), skip the install.
    if [[ ! -f "$inst" ]]; then 
        if [[ $DRY_RUN = 1 ]]; then _log war "Templates install skipped (no install script possibly due to the dry run)!" ; return; fi
        _log war "Templates install skipped (no install script)!"
        return
    fi

    # Run the install script.
    if [[ $DRY_RUN = 1 ]]; then
        _run "$inst"
        $inst --dry-run
        return
    fi
    
    $inst
}

main "$@"; exit