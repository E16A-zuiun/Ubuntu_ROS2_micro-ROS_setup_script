#!/bin/bash

set -e

if [ -f /etc/os-release ]; then
    source /etc/os-release
else
    echo "エラー: Ubuntuのバージョンを確認できませんでした。"
    exit 1
fi

if [ "$UBUNTU_CODENAME" != "jammy" ]; then
    echo "エラー: このスクリプトはROS 2 Humbleと互換性のあるUbuntu 22.04 (Jammy Jellyfish)専用です。"
    echo "現在のバージョン: $PRETTY_NAME ($UBUNTU_CODENAME)"
    echo "処理を中断します。"
    exit 1
fi

echo "UbuntuバージョンチェックOK: $PRETTY_NAME"
echo ""

echo "--- Ubuntu初期設定を開始します ---"
echo "[1/5] システムを最新の状態に更新しています..."
sudo apt update && sudo apt upgrade -y
echo "[2/5] 日本語言語パックと関連ツールをインストールしています..."
sudo apt install -y language-pack-ja manpages-ja manpages-ja-dev fcitx5-mozc dbus-x11 fonts-noto-cjk fonts-noto-cjk-extra fonts-ipafont
sudo update-locale LANG=ja_JP.UTF8
echo "[3/5] 日本語入力メソッド(Fcitx5)の環境変数を~/.bashrcに設定しています..."
if ! grep -q "export GTK_IM_MODULE=fcitx5" ~/.bashrc; then
  echo -e '\n# Fcitx5 Environment Variables\nexport GTK_IM_MODULE=fcitx5\nexport QT_IM_MODULE=fcitx5\nexport XMODIFIERS=@im=fcitx5\nexport DefaultIMModule=fcitx5' >> ~/.bashrc
fi
echo "[4/5] タイムゾーンをAsia/Tokyoに設定しています..."
sudo timedatectl set-timezone Asia/Tokyo
echo "[5/5] ~/.bashrc の設定を読み込みます..."
source ~/.bashrc
echo "--- Ubuntu初期設定が完了しました ---"
echo ""


if [ -f "/opt/ros/humble/setup.bash" ]; then
    echo "ROS 2 Humbleは既にインストールされています。インストール処理をスキップします。"
else
    echo "--- ROS2 Humbleのインストールを開始します ---"
    echo "[1/5] リポジトリ管理ツールなどをインストールしています..."
    sudo apt install -y software-properties-common
    sudo add-apt-repository universe
    echo "[2/5] ROS2のGPGキーとリポジトリを追加しています..."
    sudo apt update && sudo apt install -y curl gnupg lsb-release
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
    echo "[3/5] ROS2 Humble Desktopをインストールしています..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y ros-humble-desktop
    sudo apt install -y ros-dev-tools
    echo "[4/5] ROS2の環境変数を~/.bashrcに設定しています..."
    if ! grep -q "source /opt/ros/humble/setup.bash" ~/.bashrc; then
      echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
    fi
    echo "[5/5] ROS2のビルドツール(colcon)をインストールしています..."
    sudo apt install -y python3-colcon-common-extensions
    echo "--- ROS2 Humbleのインストールが完了しました ---"
fi

echo ""
echo "--- micro-ROSのセットアップを開始します ---"
echo "ホームディレクトリに 'microros_ws' ワークスペースを作成します。"
cd ~
mkdir -p microros_ws/src
cd microros_ws
source /opt/ros/humble/setup.bash
echo "[1/8] ワークスペース 'microros_ws' を作成しています..."
echo "[2/8] micro-ROSセットアップツールをダウンロードしています..."
if [ ! -d "src/micro_ros_setup" ]; then
    git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup
fi
echo "[3/8] rosdepを使用して依存関係を更新・インストールしています..."
sudo rosdep init || echo "rosdepは既に初期化されています。"
rosdep update
rosdep install --from-paths src --ignore-src -y
echo "[4/8] pip (Pythonパッケージインストーラー)をインストールしています..."
sudo apt-get install -y python3-pip
echo "[5/8] micro-ROSセットアップツールをビルドしています..."
colcon build
echo "[6/8] ビルドしたmicro-ROSの環境変数を~/.bashrcに設定しています..."
if ! grep -q "source $HOME/microros_ws/install/local_setup.bash" ~/.bashrc; then
  echo "source $HOME/microros_ws/install/local_setup.bash" >> ~/.bashrc
fi
source install/local_setup.bash
echo "[7/8] ファームウェアとAgentのワークスペースを作成・ビルドしています..."
ros2 run micro_ros_setup create_firmware_ws.sh freertos esp32
ros2 run micro_ros_setup build_firmware.sh
source install/local_setup.bash
ros2 run micro_ros_setup create_agent_ws.sh
source install/local_setup.bash
echo "[8/8] デフォルトのRMW実装を~/.bashrcにインストール・設定しています..."
sudo apt install --reinstall ros-humble-rmw-fastrtps-cpp ros-humble-fastrtps
if ! grep -q "export RMW_IMPLEMENTATION=rmw_microxrcedds" ~/.bashrc; then
  echo 'export RMW_IMPLEMENTATION=rmw_microxrcedds' >> ~/.bashrc
fi

echo ""
echo "--- 全てのセットアップが完了しました！ ---"
echo "ターミナルを再起動するか、'source ~/.bashrc' を実行して、すべての設定を反映させてください。"
echo "All work has been completed!"
echo "Run ‘source ~/.bashrc’ to reflect the configuration."
