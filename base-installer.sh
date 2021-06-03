#!/bin/bash
# Ubuntu/Trisquel GNU/Linux customization for Office.
# 2021 - SwITNet Ltd
# GNU GPLv3 or later.

# Check if user is root
if [ $(id -u) = 0 ]; then
   echo "Please don't run with root or sudo privileges!
  > We'll request them when necessary."
   exit 1
fi
if [ "$(pwd| grep -c "/home/")" = 0 ]; then
  echo "Please run within the users directory"
  exit
else
  echo "Let's start!"
fi

# Office use?
while [[ "$OFFICE_USE" != "yes" && "$OFFICE_USE" != "no" ]]
do
    read -p "> Is this planned to be for office use: (yes or no)"$'\n' -r OFFICE_USE
    if [ "$OFFICE_USE" = "no" ]; then
        echo "Ok, some extra packages will be added."
    elif [ "$OFFICE_USE" = "yes" ]; then
        echo "Ok, we'll stick to the office related packages only."
    fi
done

# External AppImages
## Nextcloud
while [[ "$NC_APPIMAGE" != "yes" && "$NC_APPIMAGE" != "no" ]]
do
    read -p "> Do you want to setup Nextcloud AppImage: (yes or no)"$'\n' -r NC_APPIMAGE
    if [ "$NC_APPIMAGE" = "yes" ]; then
        echo "Ok, Nextcloud AppImage will be added."
    elif [ "$NC_APPIMAGE" = "no" ]; then
        echo "Nextcloud AppImage won't be setup."
    fi
done

wait_seconds() {
secs=$(($1))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

DIST="$(lsb_release -sc)"
rename_distro() {
if [ "$DIST" = "$1" ]; then
  DIST="$2"
fi
}
#Trisquel distro renaming
rename_distro flidas xenial
rename_distro etiona bionic
rename_distro nabia  focal

# Functions
install_bundle_packages() {
for i in $1
do
  if [ "$(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed")" == "1" ]; then
      echo " > Package $i already installed."
  else
      if [ -z "$(apt-cache madison $i 2>/dev/null)" ]; then
          echo " > Package $i not available on repo."
      else
          echo " > Add package $i to the install list"
          iPackages="$iPackages $i"
      fi
  fi
done
echo "$iPackages"
if [ -z "$iPackages" ]; then
  echo "Nothing to install..."
else
  echo "Installing packages..."
  sudo apt-get -y install $iPackages
fi
}
remove_bundle_packages() {
for i in $1
do
  if [ "$(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed")" == "0" ]; then
      echo " > Package $i is not installed."
  else
      echo " > Add package $i to the remove list"
      rPackages="$rPackages $i"
  fi
done
echo "$rPackages"
if [ "$(wc -w <<< $rPackages)" = "0" ]; then
    echo "Nothing to remove..."
else
    echo "Removing packages..."
    sudo apt-get -y remove $rPackages
fi
}
set_once() {
if [ -z "$(awk '!/^ *#/ && NF {print}' "$2"|grep $(echo $1|awk -F '=' '{print$1}'))" ]; then
  echo "Setting "$1" on "$2"..."
  echo "$1" | sudo tee -a "$2"
else
  echo " \"$(echo $1|awk -F '=' '{print$1}')\" seems present, skipping setting this variable"
fi
}
change_background() {
if [ "$(lsb_release -si)" = "$1" ]; then
    if [ -f "$2" ]; then
      gsettings set org.mate.background picture-filename "$2"
    else
      echo "Check that your desired background file exists..."
    fi
fi
}

if [ "$DIST" = "bionic" ] || \
   [ "$DIST" = "focal" ]; then
    echo "OS: $(lsb_release -sd)"
    echo "Good, this is a supported platform!"
else
    echo "OS: $(lsb_release -sd)"
    echo "Sorry, this platform is not supported... exiting"
    exit
fi

sudo apt-get update
install_bundle_packages "curl \
                         net-tools \
                         ssh \
                         wget"

#Variables
NC_AppImage_API_URL="https://api.github.com/repos/nextcloud/desktop/releases/latest"
NC_ASC="https://nextcloud.com/nextcloud.asc"
NCAppImageDL="$(curl -s $NC_AppImage_API_URL | \
                awk '/browser_download_url/&&/AppImage/ {print$2}' | \
                tr -d \")"
NCAppImageBIN="$(awk '!/asc/{print}' <<< $NCAppImageDL|xargs basename)"
NCAppImageASC="$(awk '/asc/{print}' <<< $NCAppImageDL|xargs basename)"
KDENLIVE_LATEST_APPIMAGE="$(curl -s https://kdenlive.org/en/download/ | \
                            awk '/.appimage/{print}'| \
                            awk -F '[= "]' '{print$12}')"
KDENLIVE_BIN="$(echo $KDENLIVE_LATEST_APPIMAGE|xargs basename)"

gpg_libo="$(curl -s https://launchpad.net/~libreoffice/+archive/ubuntu/ppa | \
            grep 1024R| \
            awk -F'[/<]' '{print$3}' | \
            tail -c 9)"
gpg_mpv="$(curl -s https://launchpad.net/~mc3man/+archive/ubuntu/mpv-tests | \
           grep 1024R| \
           awk -F'[/<]' '{print$3}' | \
           tail -c 9)"
gpg_hb="$(curl -s https://launchpad.net/~stebbins/+archive/ubuntu/handbrake-releases | \
          grep 1024R| \
          awk -F'[/<]' '{print$3}' | \
          tail -c 9)"
gpg_x2go="$(curl -s https://launchpad.net/~x2go/+archive/ubuntu/stable | \
          grep 1024R| \
          awk -F'[/<]' '{print$3}' | \
          tail -c 9)"
BACKPORTS="$(apt-cache policy | \
            awk '/backports/{print$3}' | \
            awk -F "/" 'NR==1{print$1}')"
LIBO_REPO="$(apt-cache policy | \
            awk '/libreoffice/{print$2}' | \
            awk -F "/" 'NR==1{print$4}')"
MPV_REPO="$(apt-cache policy | \
            awk '/mpv/{print$2}' | \
            awk -F "/" 'NR==1{print$5}')"
HB_REPO="$(apt-cache policy | \
            awk '/handbrake/{print$2}' | \
            awk -F "/" 'NR==1{print$5}')"
X2GO_REPO="$(apt-cache policy | \
            awk '/x2go/{print$2}' | \
            awk -F "/" 'NR==1{print$5}')"

##Custom locale
lcl="$(env|awk -F ':' '/LANGUAGE/{print$2}')"
mfv-path="/usr/share/application/mate-font-viewer.desktop"

# == Setup ==
echo "Remove discouraged packages from system..."
remove_bundle_packages "celluloid \
                        evolution \
                        pidgin \
                        snapd \
                        transmission-gtk \
                        viewnior"

echo "Removing unused snap bits."
if [ -d $HOME/snap ]; then
  rm -rf $HOME/snap
fi

# Remove unnecesary locales
if [ "$(lsb_release -si)" = "Trisquel" ]; then
  abrowser_l10n="$(apt-cache search abrowser-locale|awk '{print$1}'|xargs)"
  ab_l10n_array=( $abrowser_l10n )
  for a in "${ab_l10n_array[@]}"; do
      if [ "$(dpkg-query -W -f='${Status}' $a 2>/dev/null | grep -c "ok installed")" == "0" ]; then
          echo " > Package $a is not installed.">/dev/null
      elif  [ $a != abrowser-locale-$lcl ] && [ $a != abrowser-locale-en ]; then
          echo " > Add package $a to the remove list"
          rAbrowser="$rAbrowser $a"
      else
          echo "> Keeping $a..."
      fi
  done

  if [ "$(wc -w <<< $rAbrowser)" = "0" ]; then
      echo "Nothing to remove..."
  else
      echo "Removing abrowser locale packages..."
      sudo apt-get -y remove $rAbrowser
  fi
#--
sudo apt-get -y remove "icedove-locale-*[!(en|$lcl)]"
sudo apt-get -y remove "libreoffice-l10n-*[!(en|$lcl)]"
fi

#Enable backports
if [ -z $BACKPORTS ]; then
  sudo sed -i '/-backports/s|#deb|deb|g' /etc/apt/sources.list
  sudo sed -i '/-backports/s|# deb|deb|g' /etc/apt/sources.list
fi

install_bundle_packages "apt-file \
                         clementine \
                         cheese \
                         filezilla \
                         font-manager \
                         git \
                         gimp \
                         gnome-disk-utility \
                         gstreamer1.0-plugins-bad \
                         gthumb \
                         kolourpaint4 \
                         mpv \
                         pdfarranger \
                         synaptic \
                         terminator \
                         thunderbird \
                         trisquel-codecs \
                         unar \
                         vlc \
                         vokoscreen"
sudo apt-file update

#Devel env
if [ "$OFFICE_USE" = "no" ]; then
install_bundle_packages "audacity \
                         bmon \
                         deluge \
                         exfalso \
                         geany \
                         htop \
                         inkscape \
                         iperf \
                         jq"

sudo apt-get install -y --no-install-recommends texlive-extra-utils
fi

# Install custom software
## - libreoffice
if [ "$(lsb_release -si)" = "Ubuntu" ] && [ -z "$LIBO_REPO" ]; then
echo "Installing LibreOffice Fresh"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_libo"
    echo "deb http://ppa.launchpad.net/libreoffice/ppa/ubuntu ${DIST} main
deb-src http://ppa.launchpad.net/libreoffice/ppa/ubuntu ${DIST} main" | \
    sudo tee /etc/apt/sources.list.d/libo-fresh.list
fi
    sudo apt-get update -q2
    rm -rf $HOME/.config/libreoffice/
    sudo apt-get -yq install libreoffice

## - x2go - desktopsharing
if [ -z "$X2GO_REPO" ]; then
echo "Installing x2go PPA"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_x2go"
    echo "deb http://ppa.launchpad.net/x2go/stable/ubuntu ${DIST} main
deb-src http://ppa.launchpad.net/x2go/stable/ubuntu ${DIST} main" | \
    sudo tee /etc/apt/sources.list.d/x2go.list
fi
    sudo apt-get update -q2
    sudo apt-get -yq install x2goserver-desktopsharing x2goclient

## - mpv
if [ -z "$MPV_REPO" ]; then
echo "Installing MPV PPA"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_mpv"
    echo "deb http://ppa.launchpad.net/mc3man/mpv-tests/ubuntu ${DIST} main
deb-src http://ppa.launchpad.net/mc3man/mpv-tests/ubuntu ${DIST} main" | \
    sudo tee /etc/apt/sources.list.d/mpv-ppa.list
fi
    sudo apt-get update -q2
    sudo apt-get -yq install mpv

# - handbreak
if [ "$(lsb_release -si)" = "Ubuntu" ] && [ -z "$HB_REPO" ]; then
echo "Installing Handbreak PPA"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_hb"
    echo "deb http://ppa.launchpad.net/stebbins/handbrake-releases/ubuntu $DIST main
deb-src http://ppa.launchpad.net/stebbins/handbrake-releases/ubuntu $DIST main" | \
    sudo tee /etc/apt/sources.list.d/hb-ppa.list
fi
  sudo apt-get update -q2
  sudo apt -yq install handbrake-gtk

# YouTube-DL
if [ -L /usr/bin/youtube-dl ] || \
   [ -f /usr/local/bin/youtube-dl ]; then
    echo "Seems youtube-dl is already installed terminal..."
    sudo youtube-dl -U
else
    sudo curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
    sudo chmod a+rx /usr/local/bin/youtube-dl
    sudo mv /usr/bin/youtube-dl /usr/bin/youtube-dl.dist.orig
    sudo ln -s /usr/local/bin/youtube-dl /usr/bin/youtube-dl
    if [ ! -f /usr/bin/python ]; then 
      sudo ln -s /usr/bin/python3 /usr/local/bin/python
      else
      echo "Python seems in place"
    fi
fi

# Further customization
## Hardcode Terminator
if [ "$(mate-terminal -v 2>/dev/null | grep -c "terminator")" == "1" ]; then
    echo "Terminator is already the default terminal..."
else
    sudo mv /usr/bin/mate-terminal /usr/bin/mate-terminal.orig
    sudo ln -s /usr/bin/terminator /usr/bin/mate-terminal
fi

# Disable mate-font-viewer
if [ -f "$mfv-path" ]; then
    mv $mfv-path ${mfv-path}-dpkg-original
fi

## inotify_watch 2^18 (default 8192)
sudo sysctl -w fs.inotify.max_user_watches=262144
set_once "fs.inotify.max_user_watches=262144" "/etc/sysctl.conf"

# AI binaries
## Nextcloud
if [ "$NC_APPIMAGE" = "yes" ]; then
    if [ ! -f $HOME/AI/$NCAppImageBIN ];then
      echo "Setting Nextcloud AppImage"
      mkdir ~/AI
      cd ~/AI
      wget -cP /tmp $NC_ASC
      wget -c $NCAppImageDL
      if [ "$(lsb_release -sc)" = "focal" ] || \
         [ "$(lsb_release -sc)" = "nabia" ]; then
        nc_fpr="$(gpg --show-keys /tmp/nextcloud.asc|awk '!/[psub]/{print$1}'|awk NF)"
      elif [ "$(lsb_release -sc)" = "bionic" ] || \
           [ "$(lsb_release -sc)" = "etiona" ]; then
        nc_fpr="$(gpg 2>/dev/null /tmp/nextcloud.asc|awk '!/[psub]/{print$1}'|awk NF)"
      fi
      gpg --import /tmp/nextcloud.asc
      echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key $nc_fpr trust

    echo "
    |------------------ Checking Nextcloud AI client GPG Signature ------------------|"
    gpg --verify $NCAppImageASC $NCAppImageBIN
    echo "    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |--------------------------------------------------------------------------------|
    "
      chmod +x $NCAppImageBIN
      rm /tmp/nextcloud.asc
      rm $NCAppImageASC
    else
      echo "Nextcloud AppImage seems already there, skiping..."
    fi
fi

## kdenlive
if [ "$KDEN_APPIMAGE" = "yes" ]; then
    if [ ! -f $HOME/AI/$KDENLIVE_BIN ];then
      echo "Setting kdenlive AppImage"
      mkdir ~/AI
      cd ~/AI
      wget -c $KDENLIVE_LATEST_APPIMAGE
      wget -c $KDENLIVE_LATEST_APPIMAGE.sha256 -O SHA256SUMS
      echo "
|------------------ Checking kdelive AI client sha256 ------------------|"
      sha256sum -c SHA256SUMS
      echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
|-----------------------------------------------------------------------|
"
      chmod +x $KDENLIVE_BIN
      rm SHA256SUMS
    else
      echo "kdenlive AppImage seems already there, skiping..."
    fi
fi

#Change background
change_background Ubuntu /usr/share/backgrounds/ubuntu-mate-photos/sebastian-muller-52.jpg
change_background Trisquel /usr/share/backgrounds/belenos3.png

echo -e "\n# Final upgrade..."
sudo apt-get update -q2
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get clean

echo "Rebooting in..."
wait_seconds 15
