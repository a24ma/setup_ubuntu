#!/usr/bin/env bash

is_executed_by_source() { return $([[ "$-" =~ "i" ]]); }
if is_executed_by_source; then
    echo "Do NOT execute by source."
    exit 1
fi

. helper.bash

main() {
    (
        sudo echo || failed_on "authentication"
        export baksuf=".bak_$(date '+%Y%m%d_%H%M%S')"
        read_conf
        setup top_dir
        setup proxy
        setup apt
        setup share
        setup c
        setup ssh
        setup git
        setup python
        setup go
        setup vscode
        setup chromium
        
        echo "Succeeded. Restart the shell or run 'source ~/.profile'".
    )
}

read_conf() {
    set -e
    if [ ! -f "setup.conf" ]; then failed_on "finding 'setup.conf'"; fi
    while read line; do
        if [[ -z "$line" ]]; then continue; fi
        if [[ "${line:0:1}" == "#" ]]; then continue; fi
        echo "Config: $(eval "echo $line")"
        export "$(eval "echo $line")"
    done < "setup.conf"
}

setup() {
    echo ""
    command="setup_${1:?usage: $0 <setup_id>}"
    enable="$(eval "echo \$enable_${command}")"
    if [[ "${enable:0:1}" != "y" ]]; then
        echo "[WARNING] Skip $command."
        return
    fi
    echo "[INFO] Run $command"
    $command || failed_on "$command"
}

setup_top_dir() {
    require top_id
    set -e
    mkdir -p ~/$top_id
    mkdir -p ~/$top_id/backup
}

setup_proxy() {
    require top_id
    require proxy
    set -e
    # Setup env
    cat <<EOF >> out
# <${top_id}_setup>
export http_proxy='$proxy'
export https_proxy='$proxy'
export ftp_proxy='$proxy'
export HTTP_PROXY='$proxy'
export HTTPS_PROXY='$proxy'
export FTP_PROXY='$proxy'
export ALL_PROXY='$proxy'
unset_proxy() {
    export http_proxy=''
    export https_proxy=''
    export ftp_proxy=''
    export HTTP_PROXY=''
    export HTTPS_PROXY=''
    export FTP_PROXY=''
    export ALL_PROXY=''
}
# </${top_id}_setup>
EOF
    edit_with_backup ~/.profile setup profile "#"

    ## Setup apt
    cat <<EOF > out
// <${top_id}_setup>
Acquire::http::proxy "$proxy";
Acquire::https::proxy "$proxy";
// </${top_id}_setup>
EOF
    sudo touch /etc/apt/apt.conf
    edit_with_backup /etc/apt/apt.conf setup apt.conf "\/\/"
}

setup_apt() {
    set -e
    sudo apt -y update
    sudo apt -y upgrade
    sudo apt -y autoremove
}

setup_share() {
    set -e
    sudo apt install -y cifs-utils
    sudo mkdir -p /mnt/Share
    clear
    mount -v | grep "/mnt/Share" || \
        sudo mount -t cifs -o uid=${myname},gid=${myname},vers=3.0,username=${smbid} $smbaddr /mnt/Share
    rm -f ~/Share
    ln -s /mnt/Share ~/Share
    cat <<EOF > ~/connect_share.bash
#!/usr/bin/env bash
mount -v | grep "/mnt/Share" || sudo mount -t cifs -o uid=${myname},gid=${myname},vers=3.0,username=${smbid} $smbaddr /mnt/Share
EOF
    chmod a+x ~/connect_share.bash
}

setup_c() {
    sudo apt install -y build-essential cmake libssl-dev
}

setup_ssh() {
    require deviceid
    sshpath=~/.ssh/rsa_$deviceid
    if [ ! -e $sshpath ]; then
        ssh-keygen -t rsa -b 4096 -C "$deviceid" -f $sshpath
    fi
}

setup_git() {
    require deviceid
    require gitemail
    require gitname
    sudo apt install -y git
    sshpath=~/.ssh/rsa_$deviceid
    echo "[INFO:SSH] Login GitHub and click Profile>Settings>SSH keys."
    echo "[INFO:SSH] Use public key: $(cat ${sshpath}.pub)"
    git config --global user.email $gitemail
    git config --global user.name $gitname
    cat <<EOF > out
# <${top_id}_git>
Host Git
    User git
    HostName github.com
    IdentityFile ~/.ssh/rsa_$deviceid
    IdentitiesOnly yes
    TCPKeepAlive yes
# </${top_id}_git>
EOF
    touch ~/.ssh/config
    edit_with_backup ~/.ssh/config git ssh_config "#"
}

setup_python() {
    require top_id
    if [ ! -e ~/.pyenv ]; then
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv        
    fi
    if [ ! -e ~/.pyenv/plugins/pyenv-virtualenv ]; then
        git clone https://github.com/yyuu/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
    fi
    cat <<EOF >> out
# <${top_id}_python>
export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"
export VIRTUAL_ENV_DISABLE_PROMPT=1
# </${top_id}_python>
EOF
    source out
    pyenv -v
    edit_with_backup ~/.bashrc python bashrc "#"

    sudo apt install -y \
        libffi-dev libssl-dev zlib1g-dev liblzma-dev \
        libbz2-dev libreadline-dev libsqlite3-dev
    for v in 2 3; do
        pyv="$(pyenv install --list | tr -d " " | grep -v [-ab] | grep "^$v" | tail -1)"
        if (pyenv versions | grep "${pyv:?'pyv not defined.'}"); then 
            echo "[INFO:PYTHON] py$v is alread installed."
        else 
            echo "[INFO:PYTHON] Install py$v (it takes a little time...)"
            pyenv install $pyv
        fi
        pyenv uninstall -f py$v
        pyenv virtualenv $pyv py$v
    done
    pyenv global py3
    printf "[INFO:PYTHON] Global version: "; pyenv version
    echo "[INFO:PYTHON] Installed versions: "; pyenv versions
}

setup_go() {
    sudo snap set system proxy.http="$proxy"
    sudo snap set system proxy.https="$proxy"
    sudo snap install go --classic
    sudo snap refresh go
    go version
}

setup_vscode() {
    # sudo snap set system proxy.http="$proxy"
    # sudo snap set system proxy.https="$proxy"
    # sudo snap install code --classic
    # sudo snap refresh code
    echo "[INFO:VSCODE] snap is outdated."
    echo "[INFO:VSCODE] Must install deb from vscode's web page."
    echo "[INFO:VSCODE] https://code.visualstudio.com/"
    echo "[INFO:VSCODE] Install vscode following command.
> sudo apt install ./vscode.deb
> sudo apt install -y apt-transport-https
> sudo apt update
"
    echo "[INFO:VSCODE] Install extension 'Settings Sync'."
    read -p "[INFO:VSCODE] Wait for installing ... (hit enter)" -n 1
}

setup_chromium() {
    sudo apt install -y chromium-browser
}

main
