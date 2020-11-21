FROM --platform=${TARGETPLATFORM:-linux/amd64} crazymax/alpine-s6:3.12

ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN printf "I am running on ${BUILDPLATFORM:-linux/amd64}, building for ${TARGETPLATFORM:-linux/amd64}\n$(uname -a)\n"

LABEL maintainer="CrazyMax"

RUN apk --update --no-cache add \
    busybox-extras \
    acl \
    bash \
    bind-tools \
    binutils \
    ca-certificates \
    coreutils \
    curl \
    fping \
    git \
    graphviz \
    imagemagick \
    ipmitool \
    mariadb-client \
    monitoring-plugins \
    mtr \
    net-snmp \
    net-snmp-tools \
    nginx \
    nmap \
    openssl \
    perl \
    php7 \
    php7-cli \
    php7-ctype \
    php7-curl \
    php7-dom \
    php7-fileinfo \
    php7-fpm \
    php7-gd \
    php7-json \
    php7-ldap \
    php7-mbstring \
    php7-mcrypt \
    php7-memcached \
    php7-mysqlnd \
    php7-opcache \
    php7-openssl \
    php7-pdo \
    php7-pdo_mysql \
    php7-pear \
    php7-phar \
    php7-posix \
    php7-session \
    php7-simplexml \
    php7-snmp \
    php7-sockets \
    php7-tokenizer \
    php7-xml \
    php7-zip \
    python3 \
    py3-pip \
    rrdtool \
    runit \
    shadow \
    su-exec \
    syslog-ng=3.27.1-r0 \
    ttf-dejavu \
    util-linux \
    whois \
  # FIXME: Remove when tzdata package updated on Alpine stable to 2020d-r0 (https://github.com/librenms/docker/issues/143)
  && apk --update --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main add \
    tzdata \
  && apk --update --no-cache add -t build-dependencies \
    build-base \
    make \
    mariadb-dev \
    musl-dev \
    python3-dev \
  && pip3 install --upgrade pip \
  && pip3 install python-memcached mysqlclient --upgrade \
  && curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
  && apk del build-dependencies \
  && rm -rf /var/cache/apk/* /var/www/* /tmp/* \
  && setcap cap_net_raw+ep /usr/bin/nmap \
  && setcap cap_net_raw+ep /usr/sbin/fping

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
  LIBRENMS_VERSION="1.69" \
  LIBRENMS_PATH="/opt/librenms" \
  LIBRENMS_DOCKER="1" \
  TZ="UTC" \
  PUID="1000" \
  PGID="1000"

RUN addgroup -g ${PGID} librenms \
  && adduser -D -h /home/librenms -u ${PUID} -G librenms -s /bin/sh -D librenms \
  && curl -sSLk -q https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro -o /usr/bin/distro \
  && chmod +x /usr/bin/distro

WORKDIR ${LIBRENMS_PATH}
RUN apk --update --no-cache add -t build-dependencies \
    build-base \
    linux-headers \
    musl-dev \
    python3-dev \
  && git clone --branch ${LIBRENMS_VERSION} https://github.com/librenms/librenms.git . \
  && pip3 install -r requirements.txt --upgrade \
  && COMPOSER_CACHE_DIR="/tmp" composer install --no-dev --no-interaction --no-ansi \
  && mkdir config.d \
  && cp config.php.default config.php \
  && cp snmpd.conf.example /etc/snmp/snmpd.conf \
  && sed -i '/runningUser/d' lnms \
  && echo "foreach (glob(\"/data/config/*.php\") as \$filename) include \$filename;" >> config.php \
  && echo "foreach (glob(\"${LIBRENMS_PATH}/config.d/*.php\") as \$filename) include \$filename;" >> config.php \
  && git clone https://github.com/librenms-plugins/Weathermap.git ./html/plugins/Weathermap \
  && chown -R nobody.nogroup ${LIBRENMS_PATH} \
  && apk del build-dependencies \
  && rm -rf .git \
    html/plugins/Test \
    html/plugins/Weathermap/.git \
    html/plugins/Weathermap/configs \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs /
RUN chmod a+x /usr/local/bin/*

EXPOSE 8000 514 514/udp
VOLUME [ "/data" ]

ENTRYPOINT [ "/init" ]
