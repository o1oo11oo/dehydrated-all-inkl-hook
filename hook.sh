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

_echo() {
    echo " + Hook: ${1}"
}

_exiterr() {
    echo "Hook ERROR: ${1}" >&2
    exit "${2:-1}"
}

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

    # send request and handle errors
    _echo "Adding DNS entry for ${DOMAIN}..."
    response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "add_dns_settings" -p "${params}" 2>&1)"
    exitval="${?}"
    if [[ "${exitval}" -eq 0 ]]; then
        if command -v dig >/dev/null; then
            # use dig for propagation checking if dnsutils are installed to skip the delay if possible
            _echo "DNS entry added successfully, waiting for propagation..."
            while ! dig TXT +trace +noall +answer "_acme-challenge.${DOMAIN}" | grep -q "${TOKEN_VALUE}"; do
                sleep 1
            done
        else
            # fallback to static wait
            _echo "DNS entry added successfully, waiting 10 seconds for propagation..."
            sleep 10
        fi
    else
        response="${response/ERROR: /}"
        _exiterr "${response}" "${exitval}"
    fi
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
    _echo "Fetching DNS entry list for ${DOMAIN}..."
    response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "get_dns_settings" -p "${get_params}" 2>&1)"
    exitval="${?}"
    if [[ "${exitval}" -eq 0 ]]; then
        _echo "DNS entry list fetched successfully."
    else
        response="${response/ERROR: /}"
        _exiterr "${response}" "${exitval}"
    fi

    # select all records starting with _acme-challenge
    local dns_entry_list="$(<<<"${response}" grep -oP '(<item xsi:type="ns2:Map">(?:(?!<item xsi:type="ns2:Map">).)*_acme-challenge(?:(?!<item xsi:type="ns2:Map">).)*)')"
    if [[ ! "${dns_entry_list}" =~ ^[[:space:]]*$ ]]; then
        readarray dns_entries <<<"${dns_entry_list}"
    else
        dns_entries=()
    fi

    # check if there are any _acme-challenge entries left to delete
    if [[ ${#dns_entries[@]} -ne 0 ]]; then
        _echo "Deleting ${#dns_entries[@]} DNS entries..."

        # general delete parameters
        delete_params="${delete_params/DOMAIN/${SLD}}"

        # delete every _acme-challenge record
        for ((i=0;i<${#dns_entries[@]};++i)); do
            # build delete request for entry i
            local params="${delete_params/ID/$(<<<"${dns_entries[i]}" grep -oP '(?<=<key xsi:type="xsd:string">record_id</key><value xsi:type="xsd:string">)[^<]+')}"

            # send delete request
            response="$("${SCRIPTDIR}"/kasapi.sh/kasapi.sh -f "delete_dns_settings" -p "${params}" 2>&1)"
            exitval="${?}"
            if [[ "${exitval}" -eq 0 ]]; then
                _echo "Successfully deleted DNS entry $(( i + 1 ))/${#dns_entries[@]}."
            else
                response="${response/ERROR: /}"
                _exiterr "${response}" "${exitval}"
            fi
        done
    fi

    exit 0
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
    exit 0
}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
    exit 0
}


HANDLER=$1; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert)$ ]]; then
  "$HANDLER" "$@"
fi
