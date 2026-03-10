#!/bin/bash
################################################################################
# install_gcli.sh — Install/upgrade gcli + cleanup legacy jaklis/silkaj
# Called by 20h12.process.sh for auto-migration of existing stations
# Can also be run standalone: ~/.zen/Astroport.ONE/tools/install_gcli.sh
#
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

LOG_TAG="[install_gcli]"
log()  { echo "$LOG_TAG $*"; }
loge() { echo "$LOG_TAG ERROR: $*" >&2; }

########################################################################
## 1. INSTALL / UPGRADE gcli (.deb from GitLab CI artifacts)
########################################################################
GCLI_API="https://git.duniter.org/api/v4/projects/clients%2Frust%2Fg1cli"

architecture=$(uname -m)
case "$architecture" in
    x86_64)  DEB_ARCH="amd64"; TARGET_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) DEB_ARCH="arm64"; TARGET_ARCH="aarch64-unknown-linux-musl" ;;
    *)
        loge "Unsupported architecture: $architecture"
        exit 1
        ;;
esac

## Fetch latest release version
GCLI_VERSION=$(curl -sL "${GCLI_API}/releases" | jq -r '.[0].tag_name' 2>/dev/null)
if [[ -z "$GCLI_VERSION" || "$GCLI_VERSION" == "null" ]]; then
    loge "Cannot fetch latest gcli version from GitLab API"
    exit 1
fi

## Check if already installed and up to date
CURRENT_VERSION=""
if command -v gcli &>/dev/null; then
    CURRENT_VERSION=$(gcli --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    LATEST_CLEAN=$(echo "$GCLI_VERSION" | sed 's/^v//')
    if [[ "$CURRENT_VERSION" == "$LATEST_CLEAN" ]]; then
        log "gcli ${CURRENT_VERSION} is already up to date"
    else
        log "gcli upgrade available: ${CURRENT_VERSION} -> ${GCLI_VERSION}"
    fi
fi

## Install or upgrade
if [[ -z "$CURRENT_VERSION" ]] || [[ "$CURRENT_VERSION" != "$(echo $GCLI_VERSION | sed 's/^v//')" ]]; then
    log "Installing gcli ${GCLI_VERSION} (.deb ${DEB_ARCH})..."

    ## Find the CI pipeline for this release tag
    PIPELINE_ID=$(curl -sL "${GCLI_API}/pipelines?ref=${GCLI_VERSION}&status=success&per_page=1" \
        | jq -r '.[0].id' 2>/dev/null)

    if [[ -z "$PIPELINE_ID" || "$PIPELINE_ID" == "null" ]]; then
        loge "No successful pipeline found for ${GCLI_VERSION}"
        exit 1
    fi

    ## Find the build job matching our target architecture
    JOB_ID=$(curl -sL "${GCLI_API}/pipelines/${PIPELINE_ID}/jobs?per_page=100" \
        | jq -r "[.[] | select(.name | test(\"${TARGET_ARCH}\"))] | .[0].id" 2>/dev/null)

    if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
        loge "No CI job found for ${TARGET_ARCH} in pipeline ${PIPELINE_ID}"
        exit 1
    fi

    DEB_NAME="g1cli_${GCLI_VERSION}-1_${DEB_ARCH}.deb"
    DEB_URL="https://git.duniter.org/clients/rust/g1cli/-/jobs/${JOB_ID}/artifacts/file/target/${TARGET_ARCH}/debian/${DEB_NAME}"

    curl -sL "$DEB_URL" -o /tmp/${DEB_NAME}
    if [[ ! -s /tmp/${DEB_NAME} ]]; then
        loge "Download failed: ${DEB_URL}"
        rm -f /tmp/${DEB_NAME}
        exit 1
    fi

    sudo dpkg -i /tmp/${DEB_NAME}
    RC=$?
    rm -f /tmp/${DEB_NAME}

    if [[ $RC -ne 0 ]]; then
        loge "dpkg install failed for ${DEB_NAME}"
        exit 1
    fi

    ## Create symlink in ~/.local/bin
    mkdir -p ~/.local/bin
    [[ $(which gcli 2>/dev/null) ]] && ln -f -s $(which gcli) ~/.local/bin/gcli

    log "gcli installed: $(gcli --version 2>/dev/null)"
fi

########################################################################
## 2. CLEANUP legacy jaklis
########################################################################
if [[ -f ~/.local/bin/jaklis ]] || command -v jaklis &>/dev/null; then
    log "Removing legacy jaklis..."
    rm -f ~/.local/bin/jaklis
    sudo rm -f /usr/local/bin/jaklis
fi

########################################################################
## 3. CLEANUP legacy silkaj
########################################################################
if [[ -f ~/.local/bin/silkaj ]] || command -v silkaj &>/dev/null; then
    log "Removing legacy silkaj..."
    rm -f ~/.local/bin/silkaj
    pip3 uninstall -y silkaj 2>/dev/null
    ## Remove silkaj source tree
    [[ -d ~/.zen/workspace/silkaj ]] && rm -rf ~/.zen/workspace/silkaj \
        && log "Removed ~/.zen/workspace/silkaj"
fi

log "Migration complete: gcli $(gcli --version 2>/dev/null | head -1)"
exit 0
