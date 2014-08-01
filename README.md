lnmp
====

auto install lnmp


#success install on centos5.x/centos6.x

#install
./lnmp_install.sh {installnginx|installmysql|installphp|installmemcached|installall|compresslnmp}

#nohup install
nohup ./lnmp_install.sh installall

#watch log
tailf install.log

#init scrpit
Usage: /etc/init.d/nginx {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}

Usage: /etc/init.d/mysqld  {start|stop|restart|reload|force-reload|status}

Usage: /etc/init.d/php-fpm {start|stop|force-quit|restart|reload|status}

Usage: /etc/init.d/memcached {start|stop|restart|condrestart|status}
