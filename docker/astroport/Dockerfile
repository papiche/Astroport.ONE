FROM debian:stable AS dist
LABEL maintainer="Fred <support@qo-op.com>"
ARG DOCKER_MACHINE=x86_64
ARG DOCKER_SYSTEM=Linux

########################################################################
## 1. SYSTEM PACKAGES (mirrors install.sh apt-get loops)
########################################################################
RUN apt-get update \
 && apt-get -fy upgrade \
 && DEBIAN_FRONTEND=noninteractive apt-get -fy install --no-install-recommends \
        # Core tools
        bash git zip make cmake sudo cron curl wget ca-certificates \
        # Network & security
        openssh-client fail2ban iptables ufw dnsutils ntpdate net-tools \
        netcat-traditional nmap socat \
        # IPFS & data
        jq bc file gawk parallel inotify-tools ncdu pv \
        # Python3 system
        pipx python3-pip python3-setuptools python3-wheel python3-dotenv \
        python3-gpg python3-jwcrypto python3-brotli python3-aiohttp \
        python3-prometheus-client python3-tk python3 \
        # Multimedia & data tools
        qrencode gnupg pandoc btop sox imagemagick ffmpeg \
        espeak vlc mp3info html2text detox basez markdown \
        geoip-bin v4l-utils ocrmypdf \
        # Crypto build deps
        cargo libsodium-dev libcurl4-openssl-dev libgpgme-dev libffi-dev \
        musl-dev openssl libssl-dev build-essential swig python3-dev \
        # ASCII art
        figlet cowsay fonts-hack-ttf \
        # Node
        npm \
        # Mail
        msmtp \
 && sed -i '/PDF/d' /etc/ImageMagick-6/policy.xml \
 && ln -f -s /usr/bin/python3 /usr/bin/python \
 && rm -rf /var/lib/apt/lists/*

########################################################################
## 2. TIDDLYWIKI
########################################################################
RUN npm install -g tiddlywiki@5.2.3

########################################################################
## 3. IPFS KUBO
########################################################################
ARG IPFS_VERSION=0.40.0
RUN OS="$(echo ${DOCKER_SYSTEM} | awk '{print tolower($0)}')" \
 && ARCH="$(echo ${DOCKER_MACHINE} | awk '{print /x86_64/ ? "amd64" : /aarch64/ ? "arm64" : /armv7l/ ? "arm" : $0}')" \
 && wget -qO - https://github.com/ipfs/kubo/releases/download/v${IPFS_VERSION}/kubo_v${IPFS_VERSION}_${OS}-${ARCH}.tar.gz \
    | tar --strip-components 1 -C /usr/local/bin -xzf - kubo/ipfs

########################################################################
## 4. SHELLCHECK + SHELLSPEC (for testing)
########################################################################
RUN OS="$(echo ${DOCKER_SYSTEM} | awk '{print tolower($0)}')" \
 && ARCH="$(echo ${DOCKER_MACHINE})" \
 && wget -qO - https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.${OS}.${ARCH}.tar.xz \
    | tar --strip-components 1 -C /usr/local/bin -xJf - shellcheck-stable/shellcheck \
 && mkdir -p /usr/local/lib/shellspec \
 && wget -qO - https://github.com/shellspec/shellspec/archive/refs/heads/master.tar.gz \
    | tar --strip-components 1 -C /usr/local/lib/shellspec -xzf - \
 && ln -s /usr/local/lib/shellspec/shellspec /usr/local/bin/shellspec

########################################################################
## 5. FLUTTER SDK (web builds for Ginkgo app)
########################################################################
ARG INSTALL_FLUTTER=true
RUN if [ "$INSTALL_FLUTTER" = "true" ]; then \
        apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get -fy install --no-install-recommends \
            unzip xz-utils clang cmake ninja-build pkg-config libgtk-3-dev \
     && rm -rf /var/lib/apt/lists/* \
     && git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter \
     && /opt/flutter/bin/flutter precache --web \
     && /opt/flutter/bin/flutter config --no-analytics \
     && /opt/flutter/bin/dart --disable-analytics; \
    fi
ENV PATH="/opt/flutter/bin:${PATH}"

########################################################################
## 6. EXPOSE PORTS (Astroport services only — NPM/NextCloud are sibling containers)
########################################################################
# 1234:  Twist BASH API (deprecated)
# 12345: Station Map / UPlanet cartography
# 33101: G1Billet
# 54321: UPassport FastAPI
# 7777:  NOSTR Relay (strfry)
# 8080:  IPFS Gateway
# 4001:  IPFS Swarm
# 5001:  IPFS API
# 45780-45782: Dynamic ports
EXPOSE 1234 12345 33101 54321 7777 8080 4001 5001 45780 45781 45782

########################################################################
## STAGE: master (user setup)
########################################################################
FROM dist AS master
ARG SHELL=/bin/bash
ARG UID=1000
ARG GID=1000
ENV USER=zen
ENV HOME=/home/zen

# Create user
RUN groupadd -g ${GID} ${USER} 2>/dev/null || true \
 && useradd -m -u ${UID} -g ${GID} -s ${SHELL} ${USER} 2>/dev/null || true \
 && echo "${USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER}

# Clone Astroport.ONE into image
RUN git clone --recurse-submodules --depth 1 \
    https://github.com/papiche/Astroport.ONE.git ${HOME}/.zen/Astroport.ONE \
 && git clone --recurse-submodules --depth 1 \
    https://github.com/papiche/UPlanet ${HOME}/.zen/workspace/UPlanet \
 && chown -R ${USER}:${USER} ${HOME}

# Switch to user for python venv + pip installs
USER ${USER}
WORKDIR ${HOME}

########################################################################
## 7. PYTHON VENV + PACKAGES (mirrors install.sh pip loop)
########################################################################
RUN python3 -m venv ${HOME}/.astro \
 && . ${HOME}/.astro/bin/activate \
 && pip install --upgrade pip setuptools wheel \
 && pipx install duniterpy --include-deps \
 && pip install -U \
    python-dotenv termcolor amzqr ollama requests geohash \
    beautifulsoup4 pyppeteer cryptography jwcrypto secp256k1 \
    gql base58 pybase64 pynacl python-gnupg pynentry \
    paho-mqtt aiohttp ipfshttpclient \
    bitcoin monero ecdsa \
    pynostr bech32 \
    matplotlib readability-lxml duniterpy \
 && rm -rf ${HOME}/.cache/pip

########################################################################
## 8. BUILD-TIME INSTALL (install_system.sh equivalent)
########################################################################
RUN mkdir -p ${HOME}/.local/bin \
 && ln -f -s ${HOME}/.zen/Astroport.ONE/tools/natools.py ${HOME}/.local/bin/natools \
 && ln -f -s ${HOME}/.zen/Astroport.ONE/tools/keygen ${HOME}/.local/bin/keygen \
 && ln -f -s ${HOME}/.zen/Astroport.ONE/command.sh ${HOME}/.local/bin/coeurbox

########################################################################
## 9. VOLUMES (persistent data across container restarts)
########################################################################
# Game data (captain account, player keys, NOSTR identities)
VOLUME ["${HOME}/.zen/game"]
# Temp/cache data (swarm, logs, IPFS cache)
VOLUME ["${HOME}/.zen/tmp"]
# IPFS repo (node identity + datastore)
VOLUME ["${HOME}/.ipfs"]
# Nginx Proxy Manager data
VOLUME ["${HOME}/.zen/nginx-proxy-manager"]

########################################################################
## 10. HEALTHCHECK
########################################################################
HEALTHCHECK --interval=60s --timeout=10s --retries=3 \
  CMD curl -sf http://127.0.0.1:54321/health > /dev/null || exit 1

########################################################################
## 11. ENTRYPOINT
########################################################################
COPY astroport.sh /app/astroport.sh
CMD ["/app/astroport.sh", "start"]
