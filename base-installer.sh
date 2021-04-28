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

# Define upstream peer
urel_orig=$(lsb_release -sc)
if [ "$urel_orig" = "flidas" ]; then
  urel="xenial"
elif [ "$urel_orig" = "etiona" ]; then
  urel="bionic"
elif [ "$urel_orig" = "nabia" ]; then
  urel="focal"
else
  urel="$(lsb_release -sc)"
fi

# Functions
install_bundle_packages() {
for i in $1
  do
     if [ "$(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed")" == "1" ]; then
     echo " > Package $i already installed."
     else
     echo " > Add package $i to the install list"
     iPackages="$iPackages $i"
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
 if [ "$(wc -w <<< $rPackages)" = "1" ]; then
   echo "Nothing to remove..."
 else
   echo "Removing packages..."
   sudo apt-get -y remove $rPackages
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

gpg_libo="$(curl -s https://launchpad.net/~libreoffice/+archive/ubuntu/ppa | \
            grep 1024R| \
            awk -F'[/<]' '{print$3}' | \
            tail -c 9)"
gpg_mpv="$(curl -s https://launchpad.net/~mc3man/+archive/ubuntu/mpv-tests | \
           grep 1024R| \
           awk -F'[/<]' '{print$3}' | \
           tail -c 9)"
gpg_hb="$(curl -s https://launchpad.net/~stebbins/+archive/ubuntu/handbrake-releases | 
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
##Custom locale
lcl="$(env | grep LANGUAGE | awk -F ':' '{print $2}')"

# == Setup ==
remove_bundle_packages "celluloid \
                        pidgin \
                        snapd \
                        transmission-gtk \
                        viewnior"

# Remove unnecesary locales
if [ "$(lsb_release -si)" = "Trisquel" ]; then
sudo apt-get -y remove "abrowser-locale-*[!(en|$lcl)]" \
                        abrowser-locale-cs \
                        abrowser-locale-de \
                        abrowser-locale-he \
                        abrowser-locale-nn \
                        abrowser-locale-zh-hans 
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
                         evolution \
                         filezilla \
                         font-manager \
                         git \
                         gimp \
                         gnome-disk-utility \
                         gstreamer1.0-plugins-bad \
                         gthumb \
                         inkscape \
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
#Devel env
if [ "$devel-env" = "yes" ]; then
install_bundle_packages "audacity \
                         bmon \
                         deluge \
                         exfalso \
                         geany \
                         htop"
sudo apt-get install -y --no-install-recommends texlive-extra-utils
fi
sudo apt-file update

# Install custom software
## - libreoffice
if [ -z "$LIBO_REPO" ]; then
echo "Installing LibreOffice Fresh"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_libo"
    echo "deb http://ppa.launchpad.net/libreoffice/ppa/ubuntu ${urel} main
deb-src http://ppa.launchpad.net/libreoffice/ppa/ubuntu ${urel} main" | \
    sudo tee /etc/apt/sources.list.d/libo-fresh.list
fi
    sudo apt-get update -q2
    rm -rf $HOME/.config/libreoffice/
    sudo apt-get -yq install libreoffice
## - mpv
if [ -z "$MPV_REPO" ]; then
echo "Installing MPV PPA"
    sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys "$gpg_mpv"
    echo "deb http://ppa.launchpad.net/mc3man/mpv-tests/ubuntu ${urel} main
deb-src http://ppa.launchpad.net/mc3man/mpv-tests/ubuntu ${urel} main" | \
    sudo tee /etc/apt/sources.list.d/mpv-ppa.list
fi
    sudo apt-get update -q2
    sudo apt-get -yq install mpv

# - handbreak
if [ "$(lsb_release -si)" = "Ubuntu" && -z "$HB_REPO" ]; then
echo "Installing Handbreak PPA"
	sudo apt-key adv -q --keyserver keyserver.ubuntu.com --recv-keys $gpg_hb
	echo "deb http://ppa.launchpad.net/stebbins/handbrake-releases/ubuntu $urel main
deb-src http://ppa.launchpad.net/stebbins/handbrake-releases/ubuntu $urel main" | \
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

sudo apt-get -y install libdvd-pkg
sudo dpkg-reconfigure libdvd-pkg

# Further customization
## Hardcode Terminator
if [ "$(mate-terminal -v 2>/dev/null | grep -c "terminator")" == "1" ]; then
    echo "Terminator is already the default terminal..."
else
    sudo mv /usr/bin/mate-terminal /usr/bin/mate-terminal.orig
    sudo ln -s /usr/bin/terminator /usr/bin/mate-terminal
fi

## inotify_watch 2^18 (default 8192)
sudo sysctl -w fs.inotify.max_user_watches=262144
if [ "$(grep -c "max_user_watches=262144" /etc/sysctl.conf)" = "0" ]; then
  echo 'fs.inotify.max_user_watches=262144' | sudo tee -a /etc/sysctl.conf
else
  echo "iNotify already set."
fi

# AI binaries
## Nextcloud
if [ ! -f $HOME/AI/$NCAppImageBIN ];then
  echo "Setting Nextcloud AppImage"
  mkdir ~/AI
  cd ~/AI
  wget -cP /tmp $NC_ASC
  wget -c $NCAppImageDL
  if [ $(lsb_release -sc) = "focal" ] || \
     [ $(lsb_release -sc) = "nabia" ]; then
    nc_fpr="$(gpg --show-keys /tmp/nextcloud.asc|awk '!/[psub]/{print$1}'|awk NF)"
  elif [ $(lsb_release -sc) = "bionic" ] || \
       [ $(lsb_release -sc) = "etiona" ]; then
    nc_fpr="$(gpg 2>/dev/null /tmp/nextcloud.asc|awk '!/[psub]/{print$1}'|awk NF)"
  fi
  gpg --import /tmp/nextcloud.asc
  echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key $nc_fpr trust
  gpg --verify $NCAppImageASC $NCAppImageBIN

  chmod +x $NCAppImageBIN
  rm /tmp/nextcloud.asc
  rm $NCAppImageASC
else
  echo "Nextcloud AppImage seems already there, skiping..."
fi

#Change background
change_background Ubuntu /usr/share/backgrounds/ubuntu-mate-photos/sebastian-muller-52.jpg
change_background Trisquel /usr/share/backgrounds/belenos3.png

echo -e "\n# Final upgrade..."
sudo apt-get update -q2
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get clean
