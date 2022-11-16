FROM debian:bullseye as dist
LABEL maintainer aynic.os <support+docker@asycn.io>
ARG DOCKER_BUILD_DIR
ARG DOCKER_MACHINE=x86_64
ARG DOCKER_SYSTEM=Linux

RUN apt-get update \
 && apt-get -fy upgrade \
 && apt-get -fy install \
        bash \
        bc \
        cron \
        curl \
        dnsutils \
        detox \
        espeak \
        fail2ban \
        file \
        ffmpeg \
        gawk \
        gettext \
        git \
        gpg \
        gpg-agent \
        html2text \
        httrack \
        imagemagick \
        inotify-tools \
        jq \
        libsodium* \
        make \
        mp3info \
        mpack \
        msmtp \
        musl-dev \
        nano \
        net-tools \
        netcat-traditional \
        nmap \
        npm \
        ntpdate \
        openssh-client \
        openssl* \
        python3 \
        python3-brotli \
        python3-dotenv \
        python3-gpg \
        python3-jwcrypto \
        python3-opencv \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        qrencode \
        screen \
        socat \
        ssmtp \
        sudo \
        tmux \
        v4l-utils \
        vlc \
        vim-nox \
        wget \
        x11-utils \
        xclip \
        xz-utils \
        youtube-dl \
        zenity \
 && sed -i '/PDF/d' /etc/ImageMagick-6/policy.xml \
 && ln -f -s  /usr/bin/python3 /usr/bin/python \
 && rm -rf /var/lib/apt/lists/*

RUN set -x && buildDeps=' \
    build-essential \
    libssl-dev \
    cargo \
    libffi-dev \
    python3-dev \
    swig \
    ' \
 && apt-get update \
 && apt-get install -y $buildDeps --no-install-recommends \
 && mkdir -p /usr/local/src/jaklis \
 && wget -qO - https://git.p2p.legal/axiom-team/jaklis/archive/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/src/jaklis -xzf - \
 && pip3 install -r /usr/local/src/jaklis/requirements.txt \
 && ln -s /usr/local/src/jaklis/jaklis.py /usr/local/bin/jaklis \
 && chmod 0755 /usr/local/bin/jaklis \
 && /usr/local/bin/jaklis --help >/dev/null \
 && mkdir -p /usr/local/src/dpgpid \
 && wget -qO - https://git.p2p.legal/aya/dpgpid/archive/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/src/dpgpid -xzf - \
 && pip3 install -r /usr/local/src/dpgpid/requirements.txt \
 && ln -s /usr/local/src/dpgpid/keygen /usr/local/bin/keygen \
 && chmod 0755 /usr/local/bin/keygen \
 && /usr/local/bin/keygen --help >/dev/null \
 && rm -rf /root/.cache \
 && apt-get clean

RUN npm install -g tiddlywiki sjcl-cli

ARG IPFS_VERSION=0.16.0

RUN { OS="$(echo ${DOCKER_SYSTEM} |awk '{print tolower($0)}')"; \
    ARCH="$(echo ${DOCKER_MACHINE})"; \
    wget -qO - https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.${OS}.${ARCH}.tar.xz \
     |tar --strip-components 1 -C /usr/local/bin -xJf - shellcheck-stable/shellcheck; } \
 && { OS="$(echo ${DOCKER_SYSTEM} |awk '{print tolower($0)}')"; \
    ARCH="$(echo ${DOCKER_MACHINE} |awk '/x86_64/ {print "amd64"}; /aarch64/ {print "arm64"}')"; \
    wget -qO - https://github.com/ipfs/kubo/releases/download/v${IPFS_VERSION}/kubo_v${IPFS_VERSION}_${OS}-${ARCH}.tar.gz \
     |tar --strip-components 1 -C /usr/local/bin -xzf - kubo/ipfs; } \
 && mkdir -p /usr/local/lib/shellspec \
 && wget -qO - https://github.com/shellspec/shellspec/archive/refs/heads/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/lib/shellspec -xzf - \
 && ln -s /usr/local/lib/shellspec/shellspec /usr/local/bin/shellspec

ADD https://raw.github.com/kvz/cronlock/master/cronlock /usr/local/bin/cronlock
RUN chmod +rx /usr/local/bin/cronlock

# config ssmtp
COPY templates/.ssmtprc /etc/ssmtp/ssmtp.conf
RUN chmod 600 /etc/ssmtp/ssmtp.conf

EXPOSE 1234 12345

COPY install.sh /install.sh
COPY ${DOCKER_BUILD_DIR}/docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]

FROM dist as master
ARG DOCKER_BUILD_DIR
ARG DOCKER_GID
ARG SHELL=/bin/bash
ARG UID
ARG USER
ENV UID=${UID}
ENV GID=${UID}
ENV USER=zen

# If we provide a numeric UID
RUN [ "$UID" -eq "$UID" ] 2>/dev/null \
# Remove user with $UID if it is not our $USER
 && if [ "$(getent passwd $UID |awk -F: '{print $1}')" != "$USER" ]; then \
      sed -i '/^'$(getent passwd $UID |awk -F: '{print $1}')':x:'$UID':/d' /etc/passwd; \
      sed -i '/^'$(getent group $GID |awk -F: '{print $1}')':x:'$GID':/d' /etc/group; \
    fi \
# Force $UID if our $USER already exists
 && sed -i 's/^'$USER':x:[0-9]\+:[0-9]\+:/'$USER':x:'$UID':'$GID':/' /etc/passwd \
 && sed -i 's/^'$USER':x:[0-9]\+:/'$USER':x:'$GID':/' /etc/group \
# Create $USER if it does not exist
 && if [ "$(getent passwd $UID)" = "" ]; then \
      echo "$USER:x:$UID:$GID::/home/$USER:$SHELL" >> /etc/passwd; \
      echo "$USER:\!:$(($(date +%s) / 60 / 60 / 24)):0:99999:7:::" >> /etc/shadow; \
      echo "$USER:x:$GID:" >> /etc/group; \
    fi \
 && mkdir -p /home/$USER \
 && chown $UID:$GID /home/$USER \
 || true

## sudo
RUN echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER"

# config ssmtp
RUN echo "$USER:support@g1sms.fr:mail.asycn.io:587" >> /etc/ssmtp/revaliases

# config crontab
RUN echo "SHELL=/bin/bash" > /var/spool/cron/crontabs/$USER \
 && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /var/spool/cron/crontabs/$USER \
 && echo "12  20  *  *  *   /bin/bash /home/zen/.zen/20h12.process.sh > /tmp/20h12.log 2>&1" >> /var/spool/cron/crontabs/$USER \
 && chown $USER /var/spool/cron/crontabs/$USER

HEALTHCHECK CMD [ $(ps aux |grep 'nc -l -p' |wc -l) -lt 199 ] && echo -n OK
USER $USER
ENV SHELL=${SHELL}
WORKDIR /home/$USER

RUN mkdir ~/.zen ~/.zen/tmp ~/astroport
