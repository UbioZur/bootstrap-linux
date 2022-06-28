# Linux Bootstrap And Setup Script

**Set of scripts to allow me to quickly deploy a new install of Linux with my configurations.**

<p align="center">
<img src="https://raw.githubusercontent.com/UbioZur/bootstrap-linux/master/screenshots/cli.jpg" alt="Screenshot of the CLI output in dry run mode." title="Dry Run CLI output." />
</p>
<p align="center">
<img src="https://raw.githubusercontent.com/UbioZur/bootstrap-linux/master/screenshots/desktop.jpg" alt="Screenshot of an example of the workstation setup." title="Workstation example." />
</p>

### Disclaimer

This repository is intended for my personal use, **YOU DO NOT WANT TO USE IT** to install on your own system, but use it as an inspiration to make your own. I have tried to document it as best as possible for learning purpose.

---

## How To Install A Fedora Linux System.

* Fedora Everything ISOs [Official download](https://alt.fedoraproject.org/)
* User creation (Non Root), Partitioning ( Disk encryption, Networking (Hostname), etc...
* Disks, Disk encryptions and partitioning, /boot/efi (non encrypted) as EFI around 200-500M, /boot (non encrypted) as ext4 around 1G.
* Networking, Set the hostname.
* Packages: `Minimal install` + `Standard` + `Common Networking Submodule`

### BASE INSTALL

* Install the dependencies, clone the repository and run the `base.sh` script.

````bash
sudo dnf install git openssl pciutils tar
mkdir -p $HOME/Projects
cd $HOME/Projects
git clone https://github.com/UbioZur/bootstrap-linux.git
cd bootstrap-linux
./base.sh -p
git remote set-url origin git@github.com:UbioZur/bootstrap-linux.git
reboot
````

````
Usage:  base.sh [-h]
        base.sh [-v] [--dry-run] [--no-color] [-q] [-l] [--log-file /path/to/log [--log-append]] [--root-ok]
               [-p] [-s https://url/to/ssh/vault] [-g https://url/to/gpg/vault] [-d git@gitprovider.com:user/dotfiles.git]
               [--cron-dotfiles ] [ -U | -u myuser ] [ -b 5 ] [-t] [--no-clean-home] [--no-docker]

Bootstrap the installation of a base linux install!

Available options:

    -h, --help          FLAG, Print this help and exit
    -v, --verbose       FLAG, Print script debug info
    --dry-run           FLAG, Display the commands the script will run.
    --root-ok           FLAG, Allow script to be run as root, usefull for container CI.

Log options:

    --no-color          FLAG, Remove style and colors from output.
    -q, --quiet         FLAG, Non error logs are not output to stderr.
    -l, --log-to-file   FLAG, Write the log to a file (Default: /var/log/base.sh.log).
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
    -b, --grub-timeout  PARAM, Time out for GRUB (default is 5).
    -t, --rpm-tainted   FLAG, Install the RPM Fusion Tainted Free.
    -n, --nvidia        FLAG, Install the NVidia Drivers (Not the nouveau ones).
    --no-clean-home     FLAG, Do not clean the $HOME folder.
    --no-docker         FLAG, Do not install and setup docker.

Development Flags (Designed to used to speedup testing during development!):

    --dev-mode          FLAG, Setup the flags bellow to speed up testing.
    --no-upgrade        FLAG, Do not upgrade the system to speed up testing.
    --no-reset-fusion   FLAG, Do not reset RPM Fusion to speed up testing.
    --no-pkg-install    FLAG, Do not install the packages to speed up testing.
    --no-sys-config     FLAG, Do not copy the system sonfiguration files.
    --no-usr-config     FLAG, Do not set up the configuration for the user.
````

### WORKSTATION

* After the base install you can use the `workstation.sh` to install the system as a workstation.

````bash
cd $HOME/Projects/bootstrap-linux
./base.sh -p
reboot
````

````
Usage:  workstation.sh [-h]
        workstation.sh [-v] [--dry-run] [--no-color] [-q] [-l] [--log-file /path/to/log [--log-append]] [--root-ok]
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
    -l, --log-to-file   FLAG, Write the log to a file (Default: /var/log/workstation.sh.log).
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
````

---

## TODO

* `Server Bootstrap`: Bootstrap script for servers.
* `Debian Bootstrap`: Debian Distribution bootstrap.
* `Virtualization`: Easy setup of virtualization.
* `Gaming`: Easy setup for gaming.
* `Automatic tests`: Use some automatic tests for CI.
* `Snapshots`: Autosetup the backups and snapshots.
* `install scripts arguments`: Match the script arguments to the install scripts arguments!

---

## License

The repo is release under the `MIT No Attribution` license.

````
MIT No Attribution License

Copyright (c) 2022 UbioZur

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
````

**TLDR:** A short, permissive software license. Basically, you can do whatever you want.
