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
    local params='{"record_name":"_acme-challengeSUBDOMAIN","record_type":"TXT","record_data":"CHALLENGE","record_aux":"0","zone_host":"DOMAIN."}'

    # check if challenge is for second level domain or subdomain
    SLD=$(<<<${DOMAIN} grep -oP '[^\.]+\.[^\.]+$')
    SUBDOMAIN="${DOMAIN/${SLD}/}"
    [[ -n ${SUBDOMAIN} ]] && SUBDOMAIN=".${SUBDOMAIN%%.}"

    # build request parameters
    params="${params/SUBDOMAIN/${SUBDOMAIN}}"
    params="${params/CHALLENGE/${TOKEN_VALUE}}"
    params="${params/DOMAIN/${SLD}}"

    response="$(${SCRIPTDIR}/kasapi.sh/kasapi.sh -f "add_dns_settings" -p "${params}")"
    exitval="${?}"
    [[ "${exitval}" -eq 0 ]] && sleep 10
    exit "${exitval}"
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
    local params='{"hostname":"DOMAIN","ssl_certificate_is_active":"Y","ssl_certificate_sni_key":"PRIVKEY","ssl_certificate_sni_crt":"CERT","ssl_certificate_sni_bundle":"CHAIN"}'

    # build request parameters
    params="${params/DOMAIN/${DOMAIN}}"
    params="${params/PRIVKEY/$(echo -n $(cat ${KEYFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"
    params="${params/CERT/$(echo -n $(cat ${CERTFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"
    params="${params/CHAIN/$(echo -n $(cat ${CHAINFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"

    response="$(${SCRIPTDIR}/kasapi.sh/kasapi.sh -f "update_ssl" -p "${params}")"
    exit "${?}"
}

HANDLER=$1; shift; $HANDLER $@
