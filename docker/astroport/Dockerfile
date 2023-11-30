FROM debian:stable as dist
LABEL maintainer aynic.os <support+docker@asycn.io>
ARG DOCKER_BUILD_DIR
ARG DOCKER_MACHINE=x86_64
ARG DOCKER_SYSTEM=Linux

RUN apt-get update \
 && apt-get -fy upgrade \
 && DEBIAN_FRONTEND=noninteractive apt-get -fy install \
        basez \
        bash \
        bc \
        ca-certificates \
        chromium \
        cmake \
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
        gnupg \
        gpg \
        gpg-agent \
        html2text \
        httrack \
        imagemagick \
        inotify-tools \
        jq \
        kodi \
        libcurl4-openssl-dev \
        libsodium* \
        make \
        miller \
        mp3info \
        mpack \
        msmtp \
        musl-dev \
        nano \
        ncdu \
        net-tools \
        netcat-traditional \
        nmap \
        npm \
        ntpdate \
        openssh-client \
        openssl* \
        pandoc \
        pv \
        python3 \
        python3-brotli \
        python3-dotenv \
        python3-gpg \
        python3-jwcrypto \
        python3-libnacl \
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
 && wget -qO - https://github.com/aynicos/jaklis/archive/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/src/jaklis -xzf - \
 && pip3 install --break-system-packages -r /usr/local/src/jaklis/requirements.txt \
 && ln -s /usr/local/src/jaklis/jaklis.py /usr/local/bin/jaklis \
 && chmod 0755 /usr/local/bin/jaklis \
 && /usr/local/bin/jaklis --help >/dev/null \
 && mkdir -p /usr/local/src/dpgpid \
 && wget -qO - https://github.com/aynicos/dpgpid/archive/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/src/dpgpid -xzf - \
 && pip3 install --break-system-packages -r /usr/local/src/dpgpid/requirements.txt \
 && ln -s /usr/local/src/dpgpid/keygen /usr/local/bin/keygen \
 && chmod 0755 /usr/local/bin/keygen \
 && /usr/local/bin/keygen --help >/dev/null \
 && pip3 install --break-system-packages amzqr pdf2docx pyppeteer \
 && rm -rf /root/.cache \
 && apt-get clean

RUN npm install -g tiddlywiki

ARG COMPOSE_REMOTE=https://github.com/docker/compose
ARG COMPOSE_VERSION=2.5.0
ARG IPFS_VERSION=0.24.0

RUN OS="$(echo ${DOCKER_SYSTEM} |awk '{print tolower($0)}')" \
 && ARCH="$(echo ${DOCKER_MACHINE} |awk '{print /armv7l/ ? "armv7" : $0}')" \
 && wget -qO /usr/bin/docker-compose ${COMPOSE_REMOTE}/releases/download/v${COMPOSE_VERSION}/docker-compose-${OS}-${ARCH} \
 && chmod +x /usr/bin/docker-compose \
 && ARCH="$(echo ${DOCKER_MACHINE})" \
 && wget -qO - https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.${OS}.${ARCH}.tar.xz \
     |tar --strip-components 1 -C /usr/local/bin -xJf - shellcheck-stable/shellcheck \
 && ARCH="$(echo ${DOCKER_MACHINE} |awk '{print /x86_64/ ? "amd64" : /arch64/ ? "arm64" : /armv(6|7)/ ? "arm" : $0}')" \
 && wget -qO - https://github.com/ipfs/kubo/releases/download/v${IPFS_VERSION}/kubo_v${IPFS_VERSION}_${OS}-${ARCH}.tar.gz \
     |tar --strip-components 1 -C /usr/local/bin -xzf - kubo/ipfs \
 && mkdir -p /usr/local/lib/shellspec \
 && wget -qO - https://github.com/shellspec/shellspec/archive/refs/heads/master.tar.gz \
     |tar --strip-components 1 -C /usr/local/lib/shellspec -xzf - \
 && ln -s /usr/local/lib/shellspec/shellspec /usr/local/bin/shellspec

ADD https://raw.github.com/kvz/cronlock/master/cronlock /usr/local/bin/cronlock
RUN chmod +rx /usr/local/bin/cronlock

# config ssmtp
COPY templates/.ssmtprc /etc/ssmtp/ssmtp.conf
RUN chmod 640 /etc/ssmtp/ssmtp.conf && chgrp mail /etc/ssmtp/ssmtp.conf

EXPOSE 1234 12345 33101 33012 45780 45781 45782 45783 45784 45785 45786 45787 45788 45789 45790

COPY install.sh /install.sh
COPY ${DOCKER_BUILD_DIR}/*.sh /app/
COPY ${DOCKER_BUILD_DIR}/.*aliases /etc/skel/
CMD ["/app/astroport.sh", "start"]

FROM dist as master
ARG DOCKER_BUILD_DIR
ARG DOCKER_GID
ARG GID
ARG SHELL=/bin/bash
ARG UID
ARG USER
ENV GID=${GID}
ENV UID=${UID}
ENV USER=zen

# If we provide a numeric UID
RUN if [ "${UID}" -eq "${UID}" ] 2>/dev/null; then \
  # Force $UID of $USER if it exists
  if [ "$(awk -F: '$1 == "'"${USER}"'" {print $3}' /etc/passwd)" != "${UID}" ]; then \
    sed -i 's/^\('"${USER}"':x\):[0-9]\+:/\1:'"${UID}"':/' /etc/passwd; \
  fi; \
  # Create $USER if $UID does not exist
  if [ "$(awk -F: '$3 == "'"${UID}"'" {print $1}' /etc/passwd)" = "" ]; then \
    echo "${USER}:x:${UID}:${GID:-${UID}}::/home/${USER}:${SHELL:-/bin/sh}" >> /etc/passwd; \
    echo "${USER}:\!:$(($(date +%s) / 60 / 60 / 24)):0:99999:7:::" >> /etc/shadow; \
    mkdir -p /home/"${USER}"; \
  fi; \
  chown "${UID}" $(awk -F: '$1 == "'"${USER}"'" {print $(NF-1)}' /etc/passwd); \
fi

# If we provide a numeric GID
RUN if [ "${GID}" -eq "${GID}" ] 2>/dev/null; then \
  # Force $GID of $GROUP if it already exists
  if [ "$(awk -F: '$1 == "'"${GROUP}"'" {print $3}' /etc/group)" != "${GID}" ]; then \
    sed -i 's/^\('"${GROUP}"':x\):[0-9]\+:/\1:'"${GID}"':/' /etc/group; \
  fi; \
  # Create $GROUP if $GID does not exist
  if [ "$(awk -F: '$3 == "'"${GID}"'" {print $1}' /etc/group)" = "" ]; then \
    echo "${GROUP}:x:${GID}:" >> /etc/group; \
  fi; \
  # Force $GID of $USER if it exists
  if [ "$(awk -F: '$1 == "'"${USER}"'" {print $4}' /etc/passwd)" != "${GID}" ]; then \
    sed -i 's/^\('"${USER}"':x:[0-9]\+\):[0-9]\+:/\1:'"${GID}"':/' /etc/passwd; \
  fi; \
  chgrp "${GID}" $(awk -F: '$1 == "'"${USER}"'" {print $(NF-1)}' /etc/passwd); \
fi

## sudo
RUN echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER"

# config ssmtp
RUN echo "$USER:support@g1sms.fr:mail.asycn.io:587" >> /etc/ssmtp/revaliases

# config crontab
RUN echo "SHELL=/bin/bash" > "/var/spool/cron/crontabs/$USER" \
 && echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> "/var/spool/cron/crontabs/$USER" \
 && echo "12  20  *  *  *   /bin/bash /home/zen/.zen/Astroport.ONE/20h12.process.sh > /tmp/20h12.log 2>&1" >> "/var/spool/cron/crontabs/$USER" \
 && chown "$USER" "/var/spool/cron/crontabs/$USER"

VOLUME "/home/$USER/.zen/game/players"

# homedir
RUN mkdir -p "/home/$USER/.zen/game/players" \
 && chown -R "$USER" "/home/$USER"

HEALTHCHECK CMD [ $(ps aux |grep 'nc -l -p' |wc -l) -lt 199 ] && echo -n OK

USER "$USER"
WORKDIR "/home/$USER"
