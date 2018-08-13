#!/usr/bin/env sh

#
# Author: KimSia, Sim (github.com/simkimsia) 
# Created: 2018-07-27
# version: 0.1

# Please go to Live Chat with NameCheap 
Namecheap_Actual_Api="https://api.namecheap.com/xml.response"
# You need to register a separate sandbox account at https://www.sandbox.namecheap.com/myaccount/signup.aspx
Namecheap_Sandbox_Api="https://api.sandbox.namecheap.com/xml.response"

## Change to sandbox if you want to test
Namecheap_Api=Namecheap_Sandbox_Api

## The API key can be found at namecheap.com > Profile section, select Tools and choose the Namecheap API Access option for Business & Dev Tools.
## API User is the account username associated with the API key
## UserName is the username of the account you are making changes on

## another thing to note is that you need to whitelist the IP address where you are calling the command from

## the code is basically `xml.response?ApiUser=<api_username>&ApiKey=<api_key>&UserName=<nc_username>&Command=<cmd_name>`

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_namecheap_add() {
  fulldomain=$1
  txtvalue=$2

  Namecheap_Key="${Namecheap_Key:-$(_readaccountconf_mutable Namecheap_Key)}"

  # run `export Namecheap_Key="API_KEY_HERE"` in terminal to ensure this works
  # to find your API_KEY_HERE go to https://ap.www.namecheap.com/settings/tools/apiaccess/
  if [ -z "$Namecheap_Key" ]; then
    Namecheap_Key=""
    _err "You don't specify namecheap api key yet."
    _err "Please create your api key and try again."
    return 1
  fi

  Namecheap_User="${Namecheap_User:-$(_readaccountconf_mutable Namecheap_User)}"

  if [ -z "$Namecheap_User" ]; then
    Namecheap_User=""
    _err "You don't specify namecheap api user yet."
    _err "Please create your api user and try again."
    return 1
  fi

  Namecheap_Username="${Namecheap_Username:-$(_readaccountconf_mutable Namecheap_User)}"

  if [ -z "$Namecheap_Username" ]; then
    Namecheap_Username=""
    _err "You don't specify namecheap username account to affect yet."
    _err "Please create your username and try again."
    return 1
  fi

  Client_IP="${Client_IP:-$(_readaccountconf_mutable Client_IP)}"

  if [ -z "$Client_IP" ]; then
    Client_IP=""
    _err "You don't specify the whitelisted client IP username account to affect yet."
    _err "Please ensure your namecheap has whitelisted your IP and specify it before trying again."
    return 1
  fi

  #save the credentials to the account conf file.
  _saveaccountconf_mutable Namecheap_Key "$Namecheap_Key"
  _saveaccountconf_mutable Namecheap_User "$Namecheap_User"
  _saveaccountconf_mutable Namecheap_Username "$Namecheap_Username"
  _saveaccountconf_mutable Client_IP "$Client_IP"

  _info "Get existing txt records for $fulldomain"
  if ! _Namecheap_request "action=QUERY&name=$fulldomain"; then
    _err "error"
    return 1
  fi

  if _contains "$response" "<Error Number"; then
    message=$(printf "%s\n" "$response" | _egrep_o '(<Error Number.*<\/Error>)')
  fi 

  if _contains "$response" "<record"; then
    _debug "get and update records"
    _qstr="action[1]=SET&type[1]=TXT&name[1]=$fulldomain&value[1]=$txtvalue"
    _qindex=2
    for t in $(echo "$response" | tr -d "\r\n" | _egrep_o '<action.*</action>' | tr "<" "\n" | grep record | grep 'type="TXT"' | cut -d '"' -f 6); do
      _debug2 t "$t"
      _qstr="$_qstr&action[$_qindex]=SET&type[$_qindex]=TXT&name[$_qindex]=$fulldomain&value[$_qindex]=$t"
      _qindex="$(_math "$_qindex" + 1)"
    done
    _Namecheap_request "$_qstr"
  else
    _debug "Just add record"
    _Namecheap_request "action=SET&type=TXT&name=$fulldomain&value=$txtvalue"
  fi

}

#fulldomain txtvalue
dns_namecheap_rm() {
  fulldomain=$1
  txtvalue=$2

  Namecheap_Key="${Namecheap_Key:-$(_readaccountconf_mutable Namecheap_Key)}"
  if [ -z "$Namecheap_Key" ]; then
    Namecheap_Key=""
    _err "You don't specify namecheap api key yet."
    _err "Please create your key and try again."
    return 1
  fi

  _Namecheap_request "action=DELETE&type=TXT&name=$fulldomain"

}

####################  Private functions below ##################################
#qstr
_Namecheap_request() {
  qstr="$1"

  _debug2 "qstr" "$qstr"

  _Namecheap_url="$Namecheap_Api?api_key=$Namecheap_Key&$qstr"
  _debug2 "_Namecheap_url" "$_Namecheap_url"
  response="$(_get "$_Namecheap_url")"

  if [ "$?" != "0" ]; then
    return 1
  fi
  _debug2 response "$response"
  _contains "$response" "<is_ok>OK:"
}

_egrep_o() {
  if ! egrep -o "$1" 2>/dev/null; then
    sed -n 's/.*\('"$1"'\).*/\1/p'
  fi
}

# inspired by dns_namecom.sh private method _namecom_get_root()
# _acme-challenge.www.domain.com
# returns
# _sub_domain=_acme-challenge.www
# _sld=domain
# _tld=com
_get_root() {
  domain=$1
  # Need to exclude the last field (tld)
  numfields=$(echo "$domain" | _egrep_o "\." | wc -l)
  _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-2)
  _tld=$(printf "%s" "$domain" | cut -d . -f 4-100)
  _sld=$(printf "%s" "$domain" | cut -d . -f 3)
  return 1
}