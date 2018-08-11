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
Namecheap_Api = Namecheap_Sandbox_Api

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
    _err "You don't specify namecheap username yet."
    _err "Please create your username and try again."
    return 1
  fi

  #save the credentials to the account conf file.
  _saveaccountconf_mutable Namecheap_Key "$Namecheap_Key"
  _saveaccountconf_mutable Namecheap_User "$Namecheap_User"
  _saveaccountconf_mutable Namecheap_Username "$Namecheap_Username"

  _info "Get existing txt records for $fulldomain"
  if ! _Namecheap_request "action=QUERY&name=$fulldomain"; then
    _err "error"
    return 1
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

# inspired by dns_me.sh private method _get_root()
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
# _domain_id=sdjkglgdfewsdfg
_get_root() {
  domain=$1
  i=2
  p=1
  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    if ! _me_rest GET "name?domainname=$h"; then
      return 1
    fi

    if _contains "$response" "\"name\":\"$h\""; then
      _domain_id=$(printf "%s\n" "$response" | _egrep_o "\"id\":[^,]*" | head -n 1 | cut -d : -f 2 | tr -d '}')
      if [ "$_domain_id" ]; then
        _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
        _domain="$h"
        return 0
      fi
      return 1
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1
}