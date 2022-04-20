#!/usr/bin/docker build .
#
# VERSION               1.0

# Clifford: latest (3.15.4 as of 2022-04-05), and previously 3.14.2, doesn't build on ppc64le - PDF::API2 error
FROM       alpine:3.13.10
MAINTAINER jirka@dutka.net

ENV HOSTNAME XoruX
ENV VI_IMAGE 1

# create file to see if this is the firstrun when started
RUN touch /firstrun

RUN apk update && apk add \
    bash \
    wget \
    supervisor \
    busybox-suid \
    apache2 \
    bc \
    net-snmp \
    net-snmp-tools \
    rrdtool \
    perl-rrd \
    perl-xml-simple \
    perl-xml-libxml \
    perl-net-ssleay \
    perl-crypt-ssleay \
    perl-net-snmp \
    net-snmp-perl \
    perl-lwp-protocol-https \
    perl-date-format \
    perl-dbd-pg \
    perl-io-tty \
    perl-want \
    # perl-font-ttf \
    net-tools \
    bind-tools \
    libxml2-utils \
    # snmp-mibs-downloader \
    openssh-client \
    ttf-dejavu \
    graphviz \
    vim \
    rsyslog \
    tzdata \
    sudo \
    less \
    ed \
    sharutils \
    make \
    tar \
    perl-dev \
    perl-app-cpanminus \
    sqlite \
    perl-dbd-pg \
    perl-dbd-sqlite \
    iproute2 \
    lsblk \
    procps \
    diffutils

# perl-font-ttf fron testing repo (needed for PDF reports)
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community perl-font-ttf
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing sblim-wbemcli

# install perl PDF API from CPAN
RUN cpanm -l /usr -n PDF::API2

# setup default user
RUN addgroup -S lpar2rrd 
RUN adduser -S lpar2rrd -G lpar2rrd -s /bin/bash
# Clifford: increase ulimits
RUN apk add linux-pam \
	&& echo '@lpar2rrd soft stack 524288' >> /etc/security/limits.conf \
	&& echo '@lpar2rrd hard stack 524288' >> /etc/security/limits.conf

# configure Apache
COPY configs/apache2/lpar2rrd.conf /etc/apache2/sites-available/
COPY configs/apache2/htpasswd /etc/apache2/conf/
COPY configs/apache2/hardening.conf /etc/apache2/conf.d

# change apache user to lpar2rrd
RUN sed -i 's/^User apache/User lpar2rrd/g' /etc/apache2/httpd.conf

# disable status module
RUN sed -i '/mod_status.so/ s/^#*/#/' /etc/apache2/httpd.conf

# add product installations
ENV LPAR_VER_MAJ "7.40"
ENV LPAR_VER_MIN ""

ENV LPAR_VER "$LPAR_VER_MAJ$LPAR_VER_MIN"

# expose ports for SSH, HTTP, HTTPS and LPAR2RRD daemon
EXPOSE 80 8162

COPY configs/crontab /var/spool/cron/crontabs/lpar2rrd
RUN chmod 640 /var/spool/cron/crontabs/lpar2rrd && chown lpar2rrd.cron /var/spool/cron/crontabs/lpar2rrd

# download tarballs from SF
# ADD http://downloads.sourceforge.net/project/lpar2rrd/lpar2rrd/$LPAR_SF_DIR/lpar2rrd-$LPAR_VER.tar /home/lpar2rrd/
# ADD http://downloads.sourceforge.net/project/stor2rrd/stor2rrd/$STOR_SF_DIR/stor2rrd-$STOR_VER.tar /home/stor2rrd/

# download tarballs from official website
ADD https://www.lpar2rrd.com/download-static/lpar2rrd/lpar2rrd-$LPAR_VER.tar /tmp/
RUN mkdir -p /opt/lpar2rrd-agent
ADD https://www.lpar2rrd.com/agent/lpar2rrd-agent-${LPAR_VER}-0.noarch.rpm /opt/lpar2rrd-agent/

# extract /opt/lpar2rrd-agent/lpar2rrd-agent.pl
RUN apk add rpm2cpio && cd / && rpm2cpio /opt/lpar2rrd-agent/lpar2rrd-agent-7.40-0.noarch.rpm | cpio -idmv
# extract lpar2rrd tarball
WORKDIR /tmp
RUN tar xvf lpar2rrd-$LPAR_VER.tar

COPY supervisord.conf /etc/
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

#RUN mkdir -p /home/lpar2rrd/lpar2rrd/data
#RUN mkdir -p /home/lpar2rrd/lpar2rrd/etc

# Clifford: Add once off steps moved from startup.sh
RUN ln -s /etc/apache2/sites-available/*.conf /etc/apache2/conf.d/
RUN echo -e "<IfModule !mpm_prefork_module>\n LoadModule cgid_module modules/mod_cgid.so\n</IfModule>\n<IfModule mpm_prefork_module>\n LoadModule cgi_module modules/mod_cgi.so\n</IfModule>" > /etc/apache2/conf.d/mod_cgi.conf
RUN mv /usr/share/vendor_perl/RRDp.pm /usr/share/perl5/vendor_perl/

VOLUME [ "/home/lpar2rrd" ]

ENTRYPOINT [ "/startup.sh" ]

