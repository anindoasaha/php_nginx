FROM centos:latest
MAINTAINER anindoasaha <anindoasaha@gmail.com>
# Dependencies for PHP
RUN yum -y update && yum clean all
RUN yum -y install libxml2 libxml2-devel curl curl-devel \
	libpng libpng-devel libjpeg libjpeg-devel libmcrypt \
	libmcrypt-devel zlib-devel libssh2 libssh2-devel libpcre3 \
	libpcre3-devel build-essential autoconf

# Install gcc and other development tools to build php and nginx
RUN yum -y groupinstall "Development Tools"

# Install libmcrypt-devel from different repo since it is not available in the official repo
RUN yum -y install epel-release && yum -y update 
RUN yum -y install libmcrypt-devel

# Create tar directory
RUN mkdir -p /tars/php-5.5.16
# Build and install PHP
COPY ["php-5.5.16", "/tars/php-5.5.16"]
RUN echo "Building PHP"
RUN cd /tars/php-5.5.16 && ls && ./configure --prefix=/usr/local/php-5.5.16 --with-jpeg-dir=/usr/local/php-5.5.16/lib \
	--enable-fpm --with-openssl --with-mcrypt --enable-bcmath --enable-calendar --enable-exif \
	--with-curl --with-gd --with-xmlrpc --with-iconv --enable-exif --enable-ftp --enable-gd-native-ttf \
	--enable-libxml --enable-sockets --enable-mbstring --enable-zip --with-zlib --enable-wddx --enable-mbregex --with-mysqli && \
	make && \
	make install
# Copy init scripts
RUN cd /tars/php-5.5.16 && cp sapi/fpm/init.d.php-fpm /usr/local/php-5.5.16/init.d.php-fpm
RUN chmod 775 /usr/local/php-5.5.16/init.d.php-fpm

# Build and install SSH2
RUN mkdir -p /tars/ssh2-0.12
COPY ["ssh2-0.12", "/tars/ssh2-0.12"]

RUN cd /tars/ssh2-0.12/ssh2-0.12 && /usr/local/php-5.5.16/bin/phpize && \
	./configure --with-php-config=/usr/local/php-5.5.16/bin/php-config --with-ssh2 && \
	make && \
	make install

# Copy configuration files to required locations
COPY ["php.ini", "/usr/local/php-5.5.16/lib/"]
COPY ["php-fpm.conf", "/usr/local/php-5.5.16/etc/"]

# FPM directory(product-specific php-fpm pool configurations go here)
RUN mkdir /usr/local/php-5.5.16/etc/fpm.d/

# Dependencies for nginx
RUN mkdir -p /tars/pcre-8.21
RUN mkdir -p /tars/nginx-1.6.0
COPY ["pcre-8.21", "/tars/pcre-8.21"]
COPY ["nginx-1.6.0", "/tars/nginx-1.6.0"]

# Build nginx
RUN cd tars/nginx-1.6.0 && ./configure --prefix=/usr/local/nginx-1.6.0 --with-pcre=../pcre-8.21 \
	--with-http_ssl_module --with-http_stub_status_module --with-http_gzip_static_module && \
	make && \
	make install

# Configuration
COPY ["nginx.conf", "/usr/local/nginx-1.6.0/conf/"]

# Create vhosts(product-specific configurations go here) and ssl directory
RUN mkdir -p /usr/local/nginx-1.6.0/conf/vhosts
RUN mkdir -p /usr/local/nginx-1.6.0/conf/ssl

# Install supervisor(used to manage multiple processes)
RUN yum -y install supervisor
RUN mkdir -p /var/log/supervisor

# This contains command to start php and nginx
COPY supervisord.conf /etc/supervisord.conf

# Expose nginx port(For container linking)(Default port, images that use this image expose their own ports as required)
EXPOSE 80

# RUN /usr/local/nginx-1.6.0/sbin/nginx && /usr/local/php-5.5.16/init.d.php-fpm start
# start.sh merely starts supervisor which starts php and nginx
COPY ["start.sh", "start.sh"]
CMD ["/bin/bash", "/start.sh"]

