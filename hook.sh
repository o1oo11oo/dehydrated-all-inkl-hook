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

    # split domain in second level domain and subdomain
    SLD=$(<<<"${DOMAIN}" grep -oP '[^\.]+\.[^\.]+$')
    SUBDOMAIN="${DOMAIN/${SLD}/}"
    [[ -n ${SUBDOMAIN} ]] && SUBDOMAIN=".${SUBDOMAIN%%.}"

    # build request parameters
    params="${params/SUBDOMAIN/${SUBDOMAIN}}"
    params="${params/CHALLENGE/${TOKEN_VALUE}}"
    params="${params/DOMAIN/${SLD}}"

    # send request
    response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "add_dns_settings" -p "${params}")"
    exitval="${?}"
    [[ "${exitval}" -eq 0 ]] && sleep 10
    exit "${exitval}"
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
    local get_params='{"zone_host":"DOMAIN."}' delete_params='{"zone_host":"DOMAIN.","record_id":"ID"}'

    # get second level domain from domain
    SLD=$(<<<"${DOMAIN}" grep -oP '[^\.]+\.[^\.]+$')

    # build get request parameters
    get_params="${get_params/DOMAIN/${SLD}}"

    # send get request
    response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "get_dns_settings" -p "${get_params}")"
    exitval="${?}"
    [[ "${exitval}" -ne 0 ]] && exit "${exitval}"

    # select all records starting with _acme-challenge
    local dns_entry_list="$(<<<"${response}" grep -oP '(<item xsi:type="ns2:Map">(?:(?!<item xsi:type="ns2:Map">).)*_acme-challenge(?:(?!<item xsi:type="ns2:Map">).)*)')"
    readarray dns_entries <<<"${dns_entry_list}"

    # check if there are any _acme-challenge entries left to delete
    if [[ ${#dns_entries[@]} -ne 0 ]]; then
        # general delete parameters
        delete_params="${delete_params/DOMAIN/${SLD}}"

        # delete every _acme-challenge record
        for ((i=0;i<${#dns_entries[@]};++i)); do
            # build delete request for entry i
            local params="${delete_params/ID/"$(<<<"${dns_entries[i]}" grep -oP '(?<=<key xsi:type="xsd:string">record_id</key><value xsi:type="xsd:string">)[^<]+')"}"

            # send delete request
            response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "delete_dns_settings" -p "${params}")"
            exitval="${?}"
            [[ "${exitval}" -ne 0 ]] && exit "${exitval}"
        done
    fi
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
    local params='{"hostname":"DOMAIN","ssl_certificate_is_active":"Y","ssl_certificate_sni_key":"PRIVKEY","ssl_certificate_sni_crt":"CERT","ssl_certificate_sni_bundle":"CHAIN"}'

    # build request parameters
    params="${params/DOMAIN/${DOMAIN}}"
    params="${params/PRIVKEY/$(echo -n $(cat ${KEYFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"
    params="${params/CERT/$(echo -n $(cat ${CERTFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"
    params="${params/CHAIN/$(echo -n $(cat ${CHAINFILE} | sed 's / \\/ g' | sed ':a;N;$!ba;s/\n/\\n/g')\\n)}"

    # send request
    response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "update_ssl" -p "${params}")"
    exit "${?}"
}

HANDLER=$1; shift; $HANDLER $@
