#!/usr/bin/env bash

# Find directory in which this script is stored by traversing all symbolic links
SOURCE="${0}"
while [ -h "${SOURCE}" ]; do # resolve ${SOURCE} until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
    SOURCE="$(readlink "${SOURCE}")"
    [[ ${SOURCE} != /* ]] && SOURCE="${DIR}/${SOURCE}" # if ${SOURCE} was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
SCRIPTDIR="${SCRIPTDIR%%/}"

function deploy_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
    local add_params='{"record_name":"_acme-challengeSUBDOMAIN","record_type":"TXT","record_data":"CHALLENGE","record_aux":"0","zone_host":"DOMAIN."}'

    # check if challenge is for second level domain or subdomain
    SLD=$(<<<${DOMAIN} grep -oP '[^\.]+\.[^\.]+$')
    SUBDOMAIN="${DOMAIN/${SLD}/}"
    [[ -n ${SUBDOMAIN} ]] && SUBDOMAIN=".${SUBDOMAIN%%.}"

    # build request parameters
    add_params="${add_params/SUBDOMAIN/${SUBDOMAIN}}"
    add_params="${add_params/CHALLENGE/${TOKEN_VALUE}}"
    add_params="${add_params/DOMAIN/${SLD}}"

    response="$(${SCRIPTDIR}/kasapi.sh/kasapi.sh -f "add_dns_settings" -p "${add_params}")"
    exitval="${?}"
    [[ "${exitval}" -eq 0 ]] && sleep 10
    exit "${exitval}"
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
}

HANDLER=$1; shift; $HANDLER $@
