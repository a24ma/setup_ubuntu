# Setup Ubuntu

Ubuntu を bash で設定するツール。

以下のことが自動(または半自動)で設定できる。

* homedir 下に作業用ディレクトリを作成(パラメータ top_id で指定)
* proxy の設定(.profile, apt を設定)
* apt の最新化
* Windows 共有ディレクトリの設定
* SSH, Git の設定 (Git への鍵登録は手動)
* 各言語設定
  * C
  * python (pyenv+virtualenv): py2 と py3 の仮想環境をデフォルトで作成(py3 が global)
  * go
* VSCode の設定 (設定共有は手動)
* Chromium の設定 (アカウント設定は手動)

バックアップ処理以外は冪等性を持つ。
以下のファイルは、内容に変更がある場合にはバックアップを取る(`~/<top_id>/backup`下)。

* ~/.profile
* ~/.bashrc
* /etc/apt/apt.conf

# Installation

```bash
cd "<directory>"              # TO BE EDITED
proxy="http://<proxy>:<port>" # TO BE EDITED

export http_proxy=$proxy
export https_proxy=$proxy
sudo cat <<EOF > /etc/apt/apt.conf
Acquire::http::proxy "$proxy";
Acquire::https::proxy "$proxy";
EOF
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y git
git clone https://github.com/a24ma/setup_ubuntu
```

# How to use

1. setup.conf のパラメータを設定。
2. `./setup.bash` を実行(setup.conf のあるディレクトリで実行すること)。
3. 再実行でスキップする場合は `enable_xxx=n` に設定(or コメントアウト)すること。
