#!/bin/sh

EXTRA_APPS=0
EXTRA_THEME=0
EXTRA_SHELL=0
EXTRA_BTSEC=0
VERBOSE=/dev/null

dev_install_print_usage() {
    cat << EOT
Setup a local development environment.

Usage: $0 [options]

Options:
  -h|--help   Show this help message
  -apps       Installs extra apps like Gimp and MySQL Workbench
  -fancy-zsh  Installs zsh with a bunch of extras
  -theme      Installs Numix circle theme
  -v          Shows verbose output
EOT
    exit
}

if [ `id -u` -eq 0 ]
then
    echo "This script may not be run as root."
    dev_install_print_usage
fi

while [ $# -ne 0 ]
do
    arg="$1"
    case "$arg" in
        -h)
            dev_install_print_usage
            ;;
        --help)
            dev_install_print_usage
            ;;
        -apps)
            EXTRA_APPS=1
            ;;
        -fancy-zsh)
            EXTRA_SHELL=1
            ;;
        -theme)
            EXTRA_THEME=1
            ;;
        -bluetooth-security)
            EXTRA_BTSEC=1
            ;;
        -v)
            VERBOSE=/dev/stdout
            ;;
    esac
    shift
done

echo Removing useless folders

rm -rf ~/Public ~/Templates ~/Videos ~/Music ~/Examples

echo Creating useful folders
for dir in bin
do
    if [ ! -d ~/$dir ]
    then
        mkdir -p ~/$dir
    fi
done

echo Installing PPA\'s

# Google Chrome
if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]
then
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -  > $VERBOSE
    sudo sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
fi

if [ "$EXTRA_BTSEC" -eq "1" ]
then
    sudo add-apt-repository --yes ppa:fixnix/indicator-systemtray-unity
fi

# WebUpd8 for Oracle java
sudo add-apt-repository --yes ppa:webupd8team/java > $VERBOSE 2>&1

# Leolik for Notify-OSD
sudo add-apt-repository --yes ppa:leolik/leolik > $VERBOSE 2>&1

echo Updating APT

sudo apt-get update > $VERBOSE

echo Upgrading APT

sudo apt-get --yes dist-upgrade > $VERBOSE

echo Installing software

echo "mysql-server mysql-server/root_password password" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password" | sudo debconf-set-selections

echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

sudo apt-get --yes --force-yes install \
    apache2 \
    build-essential \
    curl \
    dos2unix \
    dpkg-dev \
    easy-rsa \
    git \
    git-flow \
    google-chrome-stable \
    iptables-persistent \
    libapache2-mod-php5 \
    libnotify-bin \
    libnss-winbind \
    libsqlite3-dev \
    lm-sensors \
    mysql-client \
    mysql-server \
    mtpfs \
    network-manager-openvpn \
    nodejs-legacy \
    npm \
    oracle-java8-installer \
    openvpn \
    php5 \
    php5-cli \
    php5-common \
    php5-curl \
    php5-dev \
    php5-gd \
    php5-intl \
    php5-json \
    php5-mcrypt \
    php5-memcache \
    php5-memcached \
    php5-mongo \
    php5-mysql \
    php5-odbc \
    php5-readline \
    php5-redis \
    php5-sybase \
    php5-tidy \
    php5-xsl \
    php5-imagick \
    php5-xdebug  \
    php-codesniffer \
    php-invoker \
    phpmd \
    php-pear \
    php-timer \
    phpunit \
    python \
    python-pip \
    redis-server \
    redis-tools \
    ruby2.2 \
    ruby2.2-dev \
    ruby \
    ruby-dev \
    software-properties-common \
    vim \
    wget \
    whois > $VERBOSE

if [ `which grunt | wc -l` -eq "0" ]
then
    echo Installing grunt
    sudo npm install -g grunt-cli > $VERBOSE
fi

echo Configuring /etc/nsswitch.conf
sudo sed -ie 's/\(^hosts.*mdns4_minimal\) \(.*$\)/\1 wins \2/' /etc/nsswitch.conf
sudo sed -ie 's/\(wins\( wins\)*\)/wins/g' /etc/nsswitch.conf
sudo sed -ie 's/\sdns//g' /etc/nsswitch.conf
sudo sed -ie 's/files/files dns/g' /etc/nsswitch.conf

if [ ! -f ~/.gitconfig ]
then
    echo Configuring git
    echo Enter your name:
    read GIT_NAME
    echo Enter your email address:
    read GIT_EMAIL

    cat > ~/.gitconfig << EOT
[user]
name = $GIT NAME
email = $GIT_EMAIL
[alias]
ci = commit
co = checkout
shame = blame
[branch]
autosetupmerge = true
[core]
autocrlf = input
excludesfile = ~/.git-local/gitignore
[push]
default = matching
[fetch]
prune = true
[remote "origin"]
push = refs/heads/*:refs/heads/*
push = refs/tags/*:refs/tags/*
[init]
templatedir = ~/.git-local/template
EOT
fi

for dir in ~/.git-local ~/.git-local/hooks ~/.git-local/template ~/.git-local/template/hooks
do
    if [ ! -d $dir ]
    then
        mkdir -p $dir
    fi
done

if [ ! -f ~/.gitignore ]
then
    echo Creating gitignore file
    cat > ~/.gitignore << EOT
/.idea
/.rocketeer
/vendor
EOT
fi

if [ ! -f ~/.git-local/hooks/pre-commit ]
then
    echo Creating pre-commit hook file
    cat > ~/.git-local/hooks/pre-commit << "EOT"
#!/bin/bash
#
# Based on http://nrocco.github.io/2012/04/19/git-pre-commit-hook-for-PHP.html post
# and https://gist.github.com/jpetitcolas/ce00feaf19d46bfd5691
#
# Do not forget to: chmod +x .git/hooks/pre-commit

BAD_PHP_WORDS='var_dump|die|exit|ini_set|extract|__halt_compiler|eval'
BAD_JS_WORDS='console.log'
BAD_TWIG_WORDS='{{ dump(.*) }}'

EXITCODE=0
FILES=`git diff --cached --diff-filter=ACMRTUXB --name-only HEAD --`

for FILE in $FILES ; do

  if [ "${FILE:9:4}" = "core" ]; then
    echo "CORE FILE EDITED!"
    echo $FILE
    EXITCODE=1
  fi

  if [ "${FILE##*.}" = "php" ]; then
    # Run all php files through php -l and grep for `illegal` words
    /usr/bin/php -l "$FILE" > /dev/null
    if [ $? -gt 0 ]; then
      EXITCODE=1
    fi

    /bin/grep -H -i -n -E "${BAD_PHP_WORDS}" $FILE
    if [ $? -eq 0 ]; then
      EXITCODE=1
    fi
  fi

  if [ "${FILE##*.}" = "twig" ]; then
    /bin/grep -H -i -n -E "${BAD_JS_WORDS}" $FILE
    if [ $? -eq 0 ]; then
      EXITCODE=1
    fi
  fi

  if [ "${FILE##*.}" = "js" ]; then
    /bin/grep -H -i -n -E "${BAD_TWIG_WORDS}" $FILE
    if [ $? -eq 0 ]; then
      EXITCODE=1
    fi
  fi
done

if [ $EXITCODE -gt 0 ]; then
  echo
  echo 'Fix the above erros or use:'
  echo ' git commit -n'
  echo
fi

exit $EXITCODE
EOT
    chmod +x ~/.git-local/hooks/pre-commit
fi

if [ ! -L ~/.git-local/template/hooks/pre-commit ]
then
    echo Creating pre-commit hook symlink
    ln -s ~/.git-local/hooks/pre-commit ~/.git-local/template/hooks/pre-commit
fi

echo Increasing Inotify watches limit
if [ `grep fs.inotify.max_user_watches /etc/sysctl.conf | wc -l` -eq "0" ]
then
    sudo sh -c 'cat >> /etc/sysctl.conf' << EOF
fs.inotify.max_user_watches = 524288
EOF
    sudo sysctl -p
fi

if [ "$EXTRA_APPS" -eq "1" ]
then
    sudo apt-get --yes --force-yes install gimp mysql-workbench > $VERBOSE
fi

if [ "$EXTRA_SHELL" -eq "1" ]
then
    sudo apt-get --yes --force-yes install zsh powerline > $VERBOSE
    # initialize zsh
    echo Press ctrl+d or type exit if zsh does not close automatically
    zsh -c 'exit'
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" > $VERBOSE
    sudo sed -ie "s#^\($(whoami).*:\)\([^:]*\)\$#\1$(which zsh)#g" /etc/passwd
    if [ -f ~/.zshrc ]
    then
# xdebug is slow
#        if [ `grep 'alias php=' ~/.zshrc | wc -l` -eq "0" ]
#        then
#            echo "alias php='php -dzend_extension=xdebug.so'" >> ~/.zshrc
#        fi

        if [ `grep 'alias composer=' ~/.zshrc | wc -l` -eq "0" ]
        then
            echo "alias composer='composer.phar'" >> ~/.zshrc
        fi

        if [ ! -d ~/lib ]
        then
            mkdir ~/lib
        fi
        if [ ! -d ~/lib/powerline-fonts ]
        then
            git clone https://github.com/powerline/fonts.git ~/lib/powerline-fonts > $VERBOSE 2>&1
            ~/lib/powerline-fonts/install.sh > $VERBOSE
        fi
        if [ ! -d ~/lib/powerline-shell ]
        then
            git clone //github.com/milkbikis/powerline-shell.git ~/lib/powerline-shell > $VERBOSE 2>&1
            cd ~/lib/powerline-shell
            cat > config.py << EOF
SEGMENTS = [
    'ssh',
    'cwd',
    'read_only',
    'git',
    'jobs',
    'root',
]
THEME = 'default'
EOF
            ./install.py > $VERBOSE
            cd - > /dev/null
        fi
        sed -ie 's/^plugins=(.*)/plugins=(git composer cp git-flow heroku rsync redis-cli z n98-magerun)/' ~/.zshrc
        sed -ie 's/^ZSH_THEME=.*$/ZSH_THEME="agnoster"/g' ~/.zshrc
        cat >> ~/.zshrc <<"EOT"
function powerline_precmd() {
    export PS1="$(~/lib/powerline-shell/powerline-shell.py $? --shell zsh 2> /dev/null)"
}

function install_powerline_precmd() {
    for s in "${precmd_functions[@]}"; do
        if [ "$s" = "powerline_precmd" ]; then
            return
        fi
    done
    precmd_functions+=(powerline_precmd)
}

install_powerline_precmd
EOT
    fi
fi

if [ "$EXTRA_THEME" -eq "1" ]
then
    sudo apt-get --yes --force-yes install numix-gtk-theme numix-icon-theme \
        unity-tweak-tool numix-folders numix-icon-theme \
        numix-icon-theme-circle numix-plymouth-theme > $VERBOSE
fi

echo Installing mailcatcher
if [ `which mailcatcher | wc -l` -eq "0" ]
then
    sudo gem2.2 install mailcatcher > $VERBOSE
    sudo sh -c 'cat > /etc/systemd/system/mailcatcher.service' << EOF
[Unit]
Description=Ruby MailCatcher
Documentation=http://mailcatcher.me/

[Service]
EnvironmentFile=$(which mailcatcher)
Type=simple
ExecStart=$(which mailcatcher) --foreground --http-ip 127.0.0.1

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl enable mailcatcher.service > $VERBOSE
    sudo service mailcatcher start > $VERBOSE
fi

echo Configuring PHP
    sudo sh -c 'cat > /etc/php5/mods-available/custom.ini' << EOF
[PHP]
short_open_tag = On
max_execution_time = 0
max_input_vars = 100000
display_errors = On
display_startup_errors = On
post_max_size = 100M
upload_max_filesize = 101M
sendmail_path = /usr/bin/env $(which catchmail) -f test@local.dev

[Date]
date.timezone = Europe/Amsterdam

[Xdebug]
xdebug.remote_enable=1
xdebug.remote_autostart=0
xdebug.remote_host=localhost
xdebug.remote_port=9000
xdebug.profiler_enable=0
xdebug.profiler_output_dir=/tmp
xdebug.max_nesting_level=1000
xdebug.coverage_enable=1
EOF

sudo rm /etc/php5/cli/conf.d/* /etc/php5/apache2/conf.d/*

if [ ! -L /etc/php5/cli/conf.d/00-custom.ini ]
then
    sudo ln -s ../../mods-available/custom.ini /etc/php5/cli/conf.d/00-custom.ini
fi

if [ ! -L /etc/php5/cli/conf.d/05-opcache.ini ]
then
    sudo ln -s ../../mods-available/opcache.ini /etc/php5/cli/conf.d/05-opcache.ini
fi

# xdebug is slow
# for mod in curl gd imagick intl json mcrypt memcached memcache mongo mssql mysqli mysql odbc pdo pdo_dblib pdo_mysql pdo_odbc readline redis tidy xdebug xsl
for mod in curl gd imagick intl json mcrypt memcached memcache mongo mssql mysqli mysql odbc pdo pdo_dblib pdo_mysql pdo_odbc readline redis tidy xsl
do
    if [ ! -L "/etc/php5/cli/conf.d/10-${mod}.ini" ]
    then
        sudo ln -s ../../mods-available/${mod}.ini /etc/php5/cli/conf.d/10-${mod}.ini
    fi
done

sudo cp -a /etc/php5/cli/conf.d/* /etc/php5/apache2/conf.d/

# Remove xdebug from CLI because of issues with composer, resolving this via aliases
#sudo rm /etc/php5/cli/conf.d/10-xdebug.ini

echo Configuring mysql
if [ ! -f /etc/mysql/mysql.conf.d/ZZ-mysqld.cnf ]
then
    sudo sh -c 'cat > /etc/mysql/mysql.conf.d/ZZ-mysqld.cnf' <<EOT
[mysqld]
max_allowed_packet = 32M
#sql_mode=STRICT_ALL_TABLES
innodb_buffer_pool_size=1600M
ft_min_word_len=3
ft_boolean_syntax=' |-><()~*:""&^'
innodb_log_file_size = 128M
EOT
    sudo service mysql restart > $VERBOSE
fi

echo Configuring apache
sudo sed -ie "s/www-data/${USER}/g" /etc/apache2/envvars

for mod in rewrite alias auth_basic autoindex dir env filter headers ssl status mime deflate php5 negotiation mpm_prefork setenvif vhost_alias
do
    sudo a2enmod $mod > $VERBOSE 2>&1
done

for dir in private certs
do
    if [ ! -d ~/lib/ssl/$dir ]
    then
        mkdir -p ~/lib/ssl/$dir
    fi
done

if [ ! -d ~/workspace/dev.mediacthq.nl ]
then
    mkdir -p ~/workspace/dev.mediacthq.nl
fi

for file in ~/lib/ssl/private/_wildcard_.dev.mediacthq.nl.key ~/lib/ssl/certs/_wildcard_.dev.mediacthq.nl.crt ~/lib/ssl/certs/Essential.ca-bundle
do
    if [ ! -f $file ]
    then
        echo WARNING! $file not found. Download this from: https://wiki.mediact.nl/Ssl_dev.mediacthq.nl
    fi
done

sudo sed -ie 's/Listen\s*\(.*:\|\)\([0-9]*\)$/Listen 127.0.0.1:\2/g' /etc/apache2/ports.conf

if [ ! -f /etc/apache2/sites-available/_wildcard_.dev.mediacthq.nl.conf ]
then
    sudo sh -c 'cat > /etc/apache2/sites-available/_wildcard_.dev.mediacthq.nl.conf' << EOF
ServerAdmin ${USER}@localhost
AddDefaultCharset UTF-8

<Directory "/home/${USER}/workspace/dev.mediacthq.nl/">
        Options Indexes FollowSymLinks
        AllowOverride all
        Require all granted
</Directory>

<VirtualHost *:80>
    ServerName dev.mediacthq.nl
    ServerAlias *.dev.mediacthq.nl
    VirtualDocumentRoot /home/${USER}/www/%-4+
</VirtualHost>

<VirtualHost *:443>
    ServerName dev.mediacthq.nl
    ServerAlias *.dev.mediacthq.nl
    VirtualDocumentRoot /home/${USER}/www/%-4+
    SSLEngine on
    SSLProtocol all
    SSLCertificateKeyFile /home/${USER}/lib/ssl/private/_wildcard_.dev.mediacthq.nl.key
    SSLCertificateFile /home/${USER}/lib/ssl/certs/_wildcard_.dev.mediacthq.nl.crt
    SSLCACertificateFile /home/${USER}/lib/ssl/certs/Essential.ca-bundle
</VirtualHost>
EOF
fi

sudo a2ensite _wildcard_.dev.mediacthq.nl.conf > $VERBOSE 2>&1

echo Installing composer
if [ ! -f ~/bin/composer.phar ]
then
    TMP=~
    curl -sS https://getcomposer.org/installer | php -- --install-dir=${TMP}/bin > $VERBOSE
fi

echo Installing n98 magerun
if [ ! -f ~/bin/n98-magerun.phar ]
then
    wget http://files.magerun.net/n98-magerun-latest.phar -O ~/bin/n98-magerun.phar > $VERBOSE
    chmod +x ~/bin/n98-magerun.phar
fi

if [ ! -d ~/.n98-magerun/modules/ ]
then
    mkdir -p ~/.n98-magerun/modules/
fi

#if [ ! -d ~/.n98-magerun/modules/mct-dev-tools ]
#then
#    echo Installing n98 module: mediact/mct-dev-tools
#    git clone git@mediact.git.beanstalkapp.com:/mediact/mct-dev-tools.git ~/.n98-magerun/modules/mct-dev-tools > $VERBOSE 2>&1
#    cd ~/.n98-magerun/modules/mct-dev-tools
#    make composer.lock > $VERBOSE 2>&1
#    cd - > /dev/null
#fi

if [ ! -d ~/.n98-magerun/modules/environment ]
then
    echo Installing n98 module: lenlorijn/environment
    git clone git@github.com:lenlorijn/environment.git ~/.n98-magerun/modules/environment > $VERBOSE 2>&1
    cd ~/.n98-magerun/modules/environment
    php ~/bin/composer.phar install --no-dev > $VERBOSE 2>&1
    cd - > /dev/null
fi

if [ ! -d ~/.n98-magerun/modules/mpmd ]
then
    echo Installing n98 module: Magento Project Mess Detector
    git clone git@github.com:AOEpeople/mpmd.git ~/.n98-magerun/modules/mpmd > $VERBOSE 2>&1
fi

if [ "$EXTRA_BTSEC" -eq "1" ]
then
    sudo apt-get install --yes --force-yes install indicator-systemtray-unity blueproximity > $VERBOSE
fi


echo Setting pretty hostname
sudo sh -c 'cat > /etc/machine-info' << EOT
PRETTY_HOSTNAME=$(hostname)
EOT
sudo rfkill unblock bluetooth > $VERBOSE
sudo service bluetooth restart > $VERBOSE
sudo hciconfig hci0 name $(hostname) > $VERBOSE 2>&1

echo Disabling services
for service in samba smbd nmbd
do
    sudo update-rc.d $service remove
    sudo service $service stop
done

echo Restarting services
for service in bluetooth
do
    sudo service $service restart
done

echo Cleaning up installation

sudo apt-get autoclean --yes > $VERBOSE
sudo apt-get clean --yes > $VERBOSE
sudo apt-get autoremove --yes > $VERBOSE

echo <<EOF
After installing PhpStorm add the following lines to phpstorm-path/bin/phpstorm64.vmoptions:

-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
EOF

if [ "$EXTRA_APPS" -eq "1" ]
then
    echo <<EOF
Reboot is required to automatically start zsh
EOF
fi
