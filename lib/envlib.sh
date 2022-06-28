#!/usr/bin/env bash

## ---------------------------------------
## 
##   UbioZur / ubiozur.tk
##        https://git.ubiozur.tk
##
## Script name : Environement Library
## Description : A helper bash library to get useful environement information (OS / Hardware) for your script.
## Dependencies: uname, lspci
## Repository  : https://github.com/UbioZur-Tech/Templates
## License     : https://github.com/UbioZur-Tech/Templates/LICENSE
##
## ---------------------------------------

## ---------------------------------------
##   Functions to use the lib
## _os_name        : Get the distribution/OS official name. (The result is cached after first use)
## _os_version     : Get the distribution/OS version. (The result is cached after first use)
## _os_kernel      : Get the kernel. (The result is cached after first use)
## _os_hostname    : Get the hostname. (The result is cached after first use)
## _is_fedora      : Check if the distro is Fedora.
## _is_debian      : Check if the distro is Debian.
## _cpu_model      : Get the CPU model. (The result is cached after first use)
## _cpu_vendor     : Get the CPU Vendor. (The result is cached after first use)
## _cpu_cores      : Get the CPU Cores number. (The result is cached after first use)
## _cpu_threads    : Get the CPU Threads number. (The result is cached after first use)
## _gpu_list       : Get a list of GPUs available. (The result is cached after first use)
## _gpu_count      : Get the amount of GPUs available.
## _gpuis_nvidia   : Check if a GPU is NVIDIA.
## _gpuis_intel    : Check if a GPU is Intel.
## _gpuis_amd      : Check if a GPU is AMD.
## _mem_total      : Return the total amount of RAM in GB
## ---------------------------------------

## ---------------------------------------
##   Functions and global variables that should not be used by
## external programs should start with a __ (Double underscore).
## ---------------------------------------

# Avoid lib to be sourced more than once, Rename the Variable to a unique one.
[[ "${__ENVLIBLOADED:-""}" == "yes" ]] && return 0
readonly __ENVLIBLOADED="yes"

# If lib is run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

# Get the Lib file path and directory.
readonly __ENVLIB_FILE="$( readlink -f "$BASH_SOURCE" )"
readonly __ENVLIB_DIR="$( dirname "$(readlink -f "${BASH_SOURCE}")" )"

# the file to check the OS information
__OS_INFO="/etc/os-release"
# the file to check the CPU information
__CPU_INFO="/proc/cpuinfo"
# the file to check the Memory information
__MEM_INFO="/proc/meminfo"
# Cached OS/Distro information
__OS_NAME=""
__OS_VERSION=""
__OS_KERNEL=""
__OS_HOSTNAME=""
# Cached CPU information
__CPU_MODEL=""
__CPU_VENDOR=""
__CPU_CORES=""
__CPU_THREADS=""
# Cached GPU information
__GPU_LIST=""
# Cached Memory information
__MEM_TOTAL=""

## ---------------------------------------
##   Get the distribution/os name
## The value is cached inside __OS_NAME
## Usage: myvar=_os_name
## ---------------------------------------
function _os_name {
    if [[ -z "${__OS_NAME-}" ]]; then
        # distro name is in file /etc/os-release under NAME="Distro Name"
        __OS_NAME="$( grep "^NAME=" "$__OS_INFO" | sed -e 's/^NAME=//g' -e 's/\"//g' )"
    fi
    echo "$__OS_NAME"
}

## ---------------------------------------
##   Get the distribution/os version
## The value is cached inside __OS_VERSION
## Usage: myvar=_os_version
## ---------------------------------------
function _os_version {
    if [[ -z "${__OS_VERSION-}" ]]; then
        # distro version is in file /etc/os-release under VERSION="Distro Version"
        __OS_VERSION="$( grep "^VERSION=" "$__OS_INFO" | sed -e 's/^VERSION=//g' -e 's/\"//g' )"
    fi
    echo "$__OS_VERSION"
}

## ---------------------------------------
##   Get the kernel version
## The value is cached inside __OS_KERNEL
## Usage: myvar=_os_kernel
## ---------------------------------------
function _os_kernel {
    if [[ -z "${__OS_KERNEL-}" ]]; then
        # kernel version can be found with uname utility
        __OS_KERNEL="$( uname -r )"
    fi
    echo "$__OS_KERNEL"
}

## ---------------------------------------
##   Get the hostname
## The value is cached inside __OS_HOSTNAME
## Usage: myvar=_os_hostname
## ---------------------------------------
function _os_hostname {
    if [[ -z "${__OS_HOSTNAME-}" ]]; then
        # Hostname can be found with uname utility
        __OS_HOSTNAME="$( uname -n )"
    fi
    echo "$__OS_HOSTNAME"
}

## ---------------------------------------
##   Check if the distribution is Fedora
## Usage: if _is_fedora; then ... fi
## ---------------------------------------
function _is_fedora {
    local -r distro="$(_os_name)"
    [[ "$distro" =~ Fedora ]] && return
    false
}

## ---------------------------------------
##   Check if the distribution is Debian
## Usage: if _is_debian; then ... fi
## ---------------------------------------
function _is_debian {
    local -r distro="$(_os_name)"
    [[ "$distro" =~ Debian ]] && return
    false
}

## ---------------------------------------
##   Get the CPU model
## The value is cached inside __CPU_MODEL
## Usage: myvar=_cpu_model
## ---------------------------------------
function _cpu_model {
    if [[ -z "${__CPU_MODEL-}" ]]; then
        # CPU model can be found in file /proc/cpuinfo
        __CPU_MODEL="$( __my_grep 'model name' ${__CPU_INFO} | uniq | cut -d ":" -f 2 | xargs )"
    fi
    echo "$__CPU_MODEL"
}

## ---------------------------------------
##   Get the CPU Vendor
## The value is cached inside __CPU_VENDOR
## Usage: myvar=_cpu_vendor
## ---------------------------------------
function _cpu_vendor {
    if [[ -z "${__CPU_VENDOR-}" ]]; then
        # CPU model can be found in file /proc/cpuinfo
        __CPU_VENDOR="$( __my_grep 'vendor_id' ${__CPU_INFO} | uniq | cut -d ":" -f 2 | xargs )"
    fi
    echo "$__CPU_VENDOR"
}

## ---------------------------------------
##   Get the CPU Cores amount
## The value is cached inside __CPU_CORES
## Usage: myvar=_cpu_cores
## ---------------------------------------
function _cpu_cores {
    if [[ -z "${__CPU_CORES-}" ]]; then
        # CPU model can be found in file /proc/cpuinfo
        __CPU_CORES="$( __my_grep 'cpu cores' ${__CPU_INFO} | uniq | cut -d ":" -f 2 | xargs )"
    fi
    echo "$__CPU_CORES"
}

## ---------------------------------------
##   Get the CPU Threads amount
## The value is cached inside __CPU_THREADS
## Usage: myvar=_cpu_threads
## ---------------------------------------
function _cpu_threads {
    if [[ -z "${__CPU_THREADS-}" ]]; then
        # CPU model can be found in file /proc/cpuinfo
        __CPU_THREADS="$( __my_grep '^processor' ${__CPU_INFO} | wc -l )"
    fi
    echo "$__CPU_THREADS"
}

## ---------------------------------------
##   Get the GPU(s) list
## The value is cached inside __GPU_LIST
## Usage: myvar=_gpu_list
## ---------------------------------------
function _gpu_list {
    if [[ -z "${__GPU_LIST-}" ]]; then
        # make sure lspci is installed
        local -r cmd="$(command -v lspci)"
        [[ ! -x $cmd ]] && return 1
        # Get the list of gpu models
        __GPU_LIST="$( $cmd -nn | __my_grep '\[03' | uniq | cut -d ":" -f3,4 )"
    fi
    echo "$__GPU_LIST"
}

## ---------------------------------------
##   Get the amount of GPU(s)
## Usage: myvar=_gpu_count
## ---------------------------------------
function _gpu_count {
    local -r gpulist="$(_gpu_list)"
    echo "$( echo "${gpulist}" | wc -l )"
}

## ---------------------------------------
##   Check if a GPU is NVidia
## Usage: if _gpuis_nvidia; then ... fi
## ---------------------------------------
function _gpuis_nvidia {
    local -r gpulist="$(_gpu_list)"
    [[ "$gpulist" =~ NVIDIA ]] && return
    false
}

## ---------------------------------------
##   Check if a GPU is Intel
## Usage: if _gpuis_intel; then ... fi
## ---------------------------------------
function _gpuis_intel {
    local -r gpulist="$(_gpu_list)"
    [[ "$gpulist" =~ Intel ]] && return
    false
}

## ---------------------------------------
##   Check if a GPU is AMD
## Usage: if _gpuis_amd; then ... fi
## ---------------------------------------
function _gpuis_amd {
    local -r gpulist="$(_gpu_list)"
    [[ "$gpulist" =~ AMD ]] && return
    false
}

## ---------------------------------------
##   Get the total amount of RAM in GB
## The value is cached inside __MEM_TOTAL
## Usage: myvar=_mem_total
## ---------------------------------------
function _mem_total {
    if [[ -z "${__MEM_TOTAL-}" ]]; then
        local -r bytes="$( __my_grep 'MemTotal:' ${__MEM_INFO} | awk '{print $2}' | xargs )"
        __MEM_TOTAL="$(($bytes/1024/1024)) GB"
    fi
    echo "$__MEM_TOTAL"
}


## ---------------------------------------
##   Grep wrapper to catch return code error when using 
## with set -eo pipefail.
## args: same as for the grep command
## Usage: __my_grep "Thing to grep"
## ---------------------------------------
function __my_grep { 
    grep "$@" || test $? = 1;
}
