#!/bin/bash
#autor:     zaza
#create:    2014-07-18
#update:    2014-08-01
#mail:      zyqojj@gmail.com

currdir=$(cd $(dirname $0) ; pwd)
#default softdir
softdir=${currdir}/soft
[ -d ${softdir} ] || mkdir -p ${softdir}

packages="
#softurl [filename]
#url filename
#http://nginx.org/download/nginx-1.6.0.tar.gz nginx-latest.tar.gz
#1、nginx
http://nginx.org/download/nginx-1.6.0.tar.gz
#2、mysql
http://cdn.mysql.com/Downloads/MySQL-5.5/mysql-5.5.38.tar.gz
#3、php
http://cn2.php.net/distributions/php-5.5.14.tar.gz
#4、jpeg
http://www.ijg.org/files/jpegsrc.v9a.tar.gz
#5、png
http://jaist.dl.sourceforge.net/project/libpng/libpng16/1.6.12/libpng-1.6.12.tar.gz
#6、freetype
http://ncu.dl.sourceforge.net/project/freetype/freetype2/2.5.3/freetype-2.5.3.tar.gz
#7、gd
https://bbuseruploads.s3.amazonaws.com/libgd/gd-libgd/downloads/libgd-2.1.0.tar.gz?Signature=g9uA9DCJUDiMDmMPyAYc9wFlUbM%3D&Expires=1406080113&AWSAccessKeyId=0EMWEFSGA12Z1HF1TZ82 libgd-2.1.0.tar.gz
#8、memcache-3.0.8.tgz
http://pecl.php.net/get/memcache-3.0.8.tgz
#9、xxtea
http://xxtea.googlecode.com/files/xxtea.tar.gz
#10、redis
http://pecl.php.net/get/redis-2.2.5.tgz
#11、memcached
http://www.memcached.org/files/memcached-1.4.20.tar.gz
"

#install root
installroot=/usr/local

#mysql defalut password 123456
mysqlpd=TclcqmMTMDJdOonFNH5x

#source alias
shopt -s expand_aliases
. ~/.bashrc

#####################code#####################
#log_success_msg "zaza test"
#log_warning_msg "zaza test"
#log_failure_msg "zaza test"
[ -f ${currdir}/install.log ] || touch ${currdir}/install.log
function log_success_msg(){
    printf "[$(date +"%F %H:%M:%S")] %-50s              [\033[1;32mSUCCESS\033[0m]\n" "$@" | tee -a ${currdir}/install.log 
}

function log_warning_msg(){
    printf "[$(date +"%F %H:%M:%S")] %-50s              [\033[1;33;5mWARNING\033[0m]\n" "$@" | tee -a ${currdir}/install.log
}

function log_failure_msg(){
    printf "[$(date +"%F %H:%M:%S")] %-50s              [\033[1;31mFAILED\033[0m]\n" "$@" | tee -a ${currdir}/install.log
}

#download package
#download url [filename]
function download(){
    cd ${softdir}
    [ -z "$1" ] && echo "url error!" && exit 1
    local url=$1
    local file=$2
    [ -z "${file}" ] && file=${url##*/}
    
    if [ ! -f ${file} ];then
        echo "start download ${file}"
        wget --no-check-certificate -q -O $file ${url}
        #curl -sS "${url}" -o ${file}
        if [ $? -eq 0 ];then
            log_success_msg "download $file"
        else
            log_failure_msg "download $file"
            exit 1
        fi
    fi
}

#download package if not exist
dfiles(){
    echo "${packages}" | while read line  
    do
        [ -z  "$line" ] && continue    
        [[ "$line" =~ ^# ]] && continue
        #echo ${line}
        download ${line}
    done
}

#getfiles name
#getfiles nginx
function getfiles(){
    key="$1"
    echo "${packages}" | while read line
    do
        [ -z  "$line" ] && continue    
        [[ "$line" =~ ^# ]] && continue
        echo "${line}" | grep "${key}" >/dev/null
        if [ $? -eq 0 ];then
            local url=$(echo "${line}" | awk '{print $1}')
            local file=$(echo "${line}" | awk '{print $2}')
            [ -z "${file}" ] && file=${url##*/}
            echo $file
            break 2
        else
            continue
        fi
    done
}

#uncompress file and cd dir
#uncomfile file
function uncomfile(){
    cd ${softdir}
    local file=$1
    local filename=${file%.*}
    local extension=${file##*.}
    case ${extension} in
    gz|tgz)
        local dir=$(tar tf ${file} | grep / | head -n 1 | awk -F"/" '{print $1}')
        tar xzf ${file}
    ;;
    zip)
        echo "zip undefine"
    ;;
    *)
        echo unkown
    ;;
    esac
    cd ${dir}
}

#makeinstall args
function makeinstall(){
    for arg in $*
    do
        echo ${arg} | egrep "prefix|DCMAKE_INSTALL_PREFIX" >/dev/null
        if [ $? -eq 0 ];then
            local dir=$(echo ${arg} | awk -F= '{ print $2 }')
            [ -d ${dir} ] &&  log_warning_msg "${dir} exist,skip!!!" && return 1
        else
            continue
        fi
    done
    $*
    [ $? -ne 0 ] && log_failure_msg "install ${dir}" && exit 1
    return 0 
}


####install package
##install nginx
function installnginx(){
    yum -y install openssl-devel.`uname -m` pcre-devel.`uname -m`
    id -u www-data &>/dev/null || useradd www-data -M -s /bin/false
    #install -m 700 -o www-data -g www-data -d /var/log/nginx
    uncomfile $(getfiles nginx)
    makeinstall ./configure --prefix=${installroot}/nginx --user=www-data --group=www-data --with-http_stub_status_module --with-http_ssl_module
    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
    
        install -d -o www-data -g www-data -m 750 /var/log/nginx
        chmod 750 /var/log/nginx
        if [ ! -f /etc/logrotate.d/nginx ];then
            touch /etc/logrotate.d/nginx
            cat > /etc/logrotate.d/nginx <<EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 15
    compress
    delaycompress
    notifempty
    create 640 www-data www-data
    sharedscripts
    postrotate
            [ ! -f ${installroot}/nginx/logs/nginx.pid ] || kill -USR1 \`cat ${installroot}/nginx/logs/nginx.pid\`
    endscript
}
EOF
            chmod 600 /etc/logrotate.d/nginx
            chattr +i /etc/logrotate.d/nginx
        fi
        install -m 700 -o root -g root ${currdir}/scripts/nginx_centos /etc/init.d/nginx
        sed -i "s#/usr/local#${installroot}#g" /etc/init.d/nginx
        chkconfig --level 345 nginx on
        install -m 644 -o root -g root ${currdir}/conf/nginx.conf ${installroot}/nginx/conf/nginx.conf
        install -m 755 -o root -g root -d ${installroot}/nginx/conf/sites-available
        install -m 755 -o root -g root -d ${installroot}/nginx/conf/sites-enabled
        install -m 644 -o root -g root ${currdir}/conf/default.conf ${installroot}/nginx/conf/sites-available/default.conf
        install -m 644 -o root -g root ${currdir}/conf/www.temphp.com.conf ${installroot}/nginx/conf/sites-available/www.temphp.com.conf
        cd ${installroot}/nginx/conf/sites-enabled
        ln -sf ../sites-available/default.conf .
        log_success_msg "install $(getfiles nginx)"
    fi
}

##install mysql
function installmysql(){
    yum -y install gcc gcc-c++ cmake bison ncurses-devel.`uname -m`
    uncomfile $(getfiles mysql)
    makeinstall cmake . \
    -DCMAKE_INSTALL_PREFIX=${installroot}/mysql \
    -DMYSQL_DATADIR=${installroot}/mysql/data/ \
    -DDEFAULT_CHARSET=utf8 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DEXTRA_CHARSETS=big5,ascii,gb2312,gbk,utf8,latin1
    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles mysql)"
    
        echo "PATH=\$PATH:\$HOME/bin:${installroot}/mysql/bin" >> /root/.bash_profile
        echo "export PATH" >> /root/.bash_profile
        source /root/.bash_profile    
    
        id -u mysql &>/dev/null || useradd mysql -M -s /bin/false
        cd ${installroot}/mysql
        #chown -R mysql:mysql ./data
        ${installroot}/mysql/scripts/mysql_install_db --user=mysql
        cp -f support-files/my-small.cnf /etc/my.cnf
        install -c -o root -g root -m 744 support-files/mysql.server /etc/init.d/mysqld
        chkconfig --level 345 mysqld on 
        /etc/init.d/mysqld start 
    
        netstat -ntlp | grep 3306 || log_failure_msg "mysql start"
        #${installroot}/mysql/bin/mysql_secure_installation
        [ -z "${mysqlpd:-}" ] && mysqlpd=123456
        #DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        netstat -ntlp | grep 3306 && ${installroot}/mysql/bin/mysql -uroot -e " 
        UPDATE mysql.user SET Password=PASSWORD('$mysqlpd') WHERE User='root';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('127.0.0.1');
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
        DROP DATABASE test;
        FLUSH PRIVILEGES;
        "
    fi
}

##install php
function installphp(){
    #requirement
    [ ! -d ${installroot}/mysql ] && log_failure_msg "install php need mysql!!" && return 1
    yum -y install pcre-devel.`uname -m` libcurl-devel.`uname -m` libxml2-devel.`uname -m` \
    libxslt-devel.`uname -m` xmlrpc-c-devel.`uname -m` gmp-devel.`uname -m` \
    openssl-devel.`uname -m` zlib-devel.`uname -m` bzip2-devel.`uname -m` \
    libtool libxslt-devel.`uname -m` libXpm-devel.`uname -m`

    #jpeg
    uncomfile $(getfiles jpeg)
    makeinstall ./configure --prefix=${installroot}/jpeg --enable-shared --enable-static
    if [ $? -eq 0 ];then
        ln -s /usr/bin/libtool ./libtool
        mkdir -pv ${installroot}/jpeg/{bin,lib,include,man/man1,man1}
        cp jpeglib.h jerror.h jconfig.h jmorecfg.h ${installroot}/jpeg/lib
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles jpeg)" 
    fi

    #libpng
    uncomfile $(getfiles libpng)
    makeinstall ./configure --prefix=${installroot}/png
    if [ $? -eq 0 ];then
        mkdir -p ${installroot}/png
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles png)" 
    fi

    #freetype
    uncomfile $(getfiles freetype)
    makeinstall ./configure --prefix=${installroot}/freetype
    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles freetype)" 
    fi

    #gd
    uncomfile $(getfiles gd)
    makeinstall ./configure --prefix=${installroot}/gd --with-jpeg=${installroot}/jpeg/ \
    --with-png=${installroot}/png --with-zlib --with-freetype=${installroot}/freetype/
    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles gd)" 
    fi

    #php
    uncomfile $(getfiles php)
    makeinstall ./configure --prefix=${installroot}/php --with-mysql \
    --with-mysqli --with-pdo-mysql --with-curl --enable-exif --with-bz2 \
    --enable-fpm --enable-soap --with-xsl --with-openssl \
    --with-gd=${installroot}/gd/ --with-jpeg-dir=${installroot}/jpeg \
    --with-zlib --with-png-dir=${installroot}/png --with-gettext \
    --with-freetype-dir=${installroot}/freetype --with-iconv \
    --enable-sockets --enable-mbstring --with-xmlrpc \
    --with-gmp --with-fpm-user=www-data --with-fpm-group=www-data \
    --with-xpm-dir=/usr/lib64/ --enable-opcache

    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles php)" 
    
        install -c -o root -g root -m 744 ./sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
        chkconfig --level 345 php-fpm on
        cp php.ini-production ${installroot}/php/lib/php.ini
        cp ${installroot}/php/etc/php-fpm.conf.default ${installroot}/php/etc/php-fpm.conf

        #add extension
        grep "extension=redis.so" ${installroot}/php/lib/php.ini > /dev/null || \
        sed -i '/;extension=php_xsl.dll/a extension=redis.so' ${installroot}/php/lib/php.ini
        grep "extension=xxtea.so" ${installroot}/php/lib/php.ini > /dev/null || \
        sed -i '/;extension=php_xsl.dll/a extension=xxtea.so' ${installroot}/php/lib/php.ini
        grep "extension=memcache.so" ${installroot}/php/lib/php.ini > /dev/null || \
        sed -i '/;extension=php_xsl.dll/a extension=memcache.so' ${installroot}/php/lib/php.ini

        sed -i '/;date.timezone =/a date.timezone = Asia/Chongqing' ${installroot}/php/lib/php.ini

        #secure:disable_functions
        sed -i "s/disable_functions =.*/disable_functions = \
exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,chroot,chgrp,chown,dl,fsocket,\
proc_close,proc_open,dl,popen,show_source,syslog,readlink,symlink,proc_get_status,fsockopen,\
popepassthru,stream_socket_server,scandir,error_reporting,ini_alter,ini_set,ini_restore,phpinfo/g" \
${installroot}/php/lib/php.ini

        #Restricted access path (/tmp can wildcard /tmpbala, so you need written /tmp/)
        #Priority nginx server > [HOST=a.com] > open_basedir
        sed -i '/;open_basedir =/a open_basedir = \/var\/www/:\/tmp/' ${installroot}/php/lib/php.ini        

        #Individual site settings (in php.ini final pieces to append text below)
        #[HOST=a.com]
        #open_basedir=/var/www/a.com/:/tmp/
        #[HOST=b.com]
        #open_basedir=/var/www/b.com/:/tmp/

        #add into nginx conf server
        #fastcgi_param  PHP_VALUE  open_basedir="$document_root/:/tmp/";
        #test：Visit the phpinfo and search open_basedir
        
        id -u www-data &>/dev/null || useradd www-data -M -s /bin/false
        install -d -o www-data -g www-data -m 750 /var/log/php
        sed -i '/;error_log = syslog/a error_log = \/var\/log\/php\/php_errors.log' ${installroot}/php/lib/php.ini
        
        #close upload
        sed -i 's/file_uploads = On/file_uploads = Off/g' ${installroot}/php/lib/php.ini
        
        #close display php version
        sed -i 's/expose_php = On/expose_php = Off/g' ${installroot}/php/lib/php.ini

        #used instead of curl
        sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/g' ${installroot}/php/lib/php.ini

        #opcache config
        sed -i '/\[opcache\]/a zend_extension=opcache.so\n' ${installroot}/php/lib/php.ini
        sed -i '/;opcache.memory_consumption=64/a opcache.memory_consumption=128' ${installroot}/php/lib/php.ini
        sed -i '/;opcache.interned_strings_buffer=4/a opcache.interned_strings_buffer=8' ${installroot}/php/lib/php.ini
        sed -i '/;opcache.max_accelerated_files=2000/a opcache.max_accelerated_files=4000' ${installroot}/php/lib/php.ini
        sed -i '/;opcache.revalidate_freq=2/a opcache.revalidate_freq=60' ${installroot}/php/lib/php.ini
        sed -i '/;opcache.fast_shutdown=0/a opcache.fast_shutdown=1' ${installroot}/php/lib/php.ini
        #cli use for debug
        #sed -i '/;opcache.enable_cli=0/a opcache.enable_cli=1' ${installroot}/php/lib/php.ini

        #php-fpm.conf
        sed -i 's/^pm.max_children.*/pm.max_children = 256/g' ${installroot}/php/etc/php-fpm.conf
        sed -i 's/^pm.start_servers.*/pm.start_servers = 32/g' ${installroot}/php/etc/php-fpm.conf
        sed -i 's/^pm.min_spare_servers.*/pm.min_spare_servers = 16/g' ${installroot}/php/etc/php-fpm.conf
        sed -i 's/^pm.max_spare_servers.*/pm.max_spare_servers = 256/g' ${installroot}/php/etc/php-fpm.conf 

        ##extensions
        #memcache
        uncomfile $(getfiles memcache-)
        makeinstall ${installroot}/php/bin/phpize
        makeinstall ./configure --enable-memcache --with-php-config=${installroot}/php/bin/php-config
        makeinstall make
        makeinstall make install
        log_success_msg "install php extension: memcache" 

        #xxtea
        uncomfile $(getfiles xxtea)
        makeinstall ${installroot}/php/bin/phpize
        makeinstall ./configure --enable-xxtea=shared --with-php-config=${installroot}/php/bin/php-config
        makeinstall make
        makeinstall make install
        log_success_msg "install php extension: xxtea" 

        #redis
        uncomfile $(getfiles redis)
        makeinstall ${installroot}/php/bin/phpize
        makeinstall ./configure --with-php-config=${installroot}/php/bin/php-config
        makeinstall make
        makeinstall make install
        log_success_msg "install php extension: redis"

        #check extension
        extensions="curl bz2 gd gettext gmp iconv json libxml mbstring memcache mysql mysqli openssl pcre redis sockets xml xmlrpc xsl xxtea zlib OPcache"
        for ext in ${extensions};do
            ${installroot}/php/sbin/php-fpm -m | grep ${ext} >/dev/null || log_failure_msg "php extension not exist: ${ext}"
        done
    fi
}

#memcached
function installmemcached(){
    yum -y install libevent-devel.`uname -m`
    uncomfile $(getfiles memcached)
    makeinstall ./configure --prefix=${installroot}/memcached --with-libevent=/usr
    if [ $? -eq 0 ];then
        makeinstall make
        makeinstall make install
        log_success_msg "install $(getfiles memcached)"
        install -m 700 -o root -g root ${currdir}/scripts/memcached /etc/init.d/memcached
        sed -i "s#/usr/local#${installroot}#g" /etc/init.d/memcached
        chkconfig --level 345 memcached on
    fi
}

#download
if [ ! -z "$1" -a "$1" != compresslnmp ];then
    dfiles
    yum -y install gcc-c++.`uname -m`
fi

case $1 in
installnginx)
    installnginx
;;
installmysql)
    installmysql
;;
installphp)
    installphp
;;
installmemcached)
    installmemcached
;;
installall)
    installnginx
    installmysql
    installphp
    installmemcached
;;
compresslnmp)
    cd ${currdir}/..;[ -f lnmp.tar.gz ] && rm -f lnmp.tar.gz ;tar -cvzf lnmp.tar.gz lnmp/scripts lnmp/conf lnmp/soft/*gz lnmp/lnmp_install.sh lnmp/README.md
    echo -e "\n\npath: $(pwd)/lnmp.tar.gz"
;;
*)
    echo "./lnmp_install.sh {installnginx|installmysql|installphp|installmemcached|installall|compresslnmp}"
;;
esac
