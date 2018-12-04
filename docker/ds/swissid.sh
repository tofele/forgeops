#!/usr/bin/env bash
# Source this to set standard environment variables

export CTS_PW_FILE="${CTS_PW_FILE:-$SECRET_PATH/cts.pw}"
export USERSTORE_PW_FILE="${USERSTORE_PW_FILE:-$SECRET_PATH/userstore.pw}"
export CONFIGSTORE_PW_FILE="${CONFIGSTORE_PW_FILE:-$SECRET_PATH/configstore.pw}"

export SELFMANAGEMENT_PW_FILE="${SELFMANAGEMENT_PW_FILE:-$SECRET_PATH/selfmanagement.pw}"
export SUPPORT_PW_FILE="${SUPPORT_PW_FILE:-$SECRET_PATH/support.pw}"
export IDCHECK_PW_FILE="${IDCHECK_PW_FILE:-$SECRET_PATH/idcheck.pw}"
export SWISSIDAPP_PW_FILE="${SWISSIDAPP_PW_FILE:-$SECRET_PATH/swissidapp.pw}"

export BACKUP_PW_FILE="${BACKUP_PW_FILE:-$SECRET_PATH/backup.pw}"
export MONITOR_PW_FILE="${MONITOR_PW_FILE:-$SECRET_PATH/monitor.pw}"

export ACCOUNTMGR_PW_FILE="${ACCOUNTMGR_PW_FILE:-$SECRET_PATH/accountmgr.pw}"

CTS_PW=$( cat $CTS_PW_FILE )
USERSTORE_PW=$( cat $USERSTORE_PW_FILE )
CONFIGSTORE_PW=$( cat $CONFIGSTORE_PW_FILE )

SELFMANAGEMENT_PW=$( cat $SELFMANAGEMENT_PW_FILE )
SUPPORT_PW=$( cat $SUPPORT_PW_FILE )
IDCHECK_PW=$( cat $IDCHECK_PW_FILE )
SWISSIDAPP_PW=$( cat $SWISSIDAPP_PW_FILE )

BACKUP_PW=$( cat $BACKUP_PW_FILE )
MONITOR_PW=$( cat $MONITOR_PW_FILE )

ACCOUNTMGR_PW=$( cat $ACCOUNTMGR_PW_FILE )

update_swissid_passwords() {
  echo "Updating SwissID LDAP passwords"
  bin/ldapmodify -h localhost -p 1389 -D "cn=Directory Manager" -j ${DIR_MANAGER_PW_FILE} <<EOF
dn: uid=openam_cts,ou=admins,ou=famrecords,ou=openam-session,ou=tokens
changetype: modify
replace: userPassword
userPassword: $CTS_PW

dn: uid=am-identity-bind-account,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $USERSTORE_PW

dn: uid=am-config,ou=admins,ou=am-config
changetype: modify
replace: userPassword
userPassword: $CONFIGSTORE_PW

dn: uid=backup,ou=admins,ou=famrecords,ou=openam-session,ou=tokens
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=backup,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=backup,ou=admins,ou=am-config
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=jmxmonitoring,ou=admins,ou=famrecords,ou=openam-session,ou=tokens
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

dn: uid=jmxmonitoring,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

dn: uid=jmxmonitoring,ou=admins,ou=am-config
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

dn: uid=selfmanagement,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SELFMANAGEMENT_PW

dn: uid=support,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SUPPORT_PW

dn: uid=idcheck,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $IDCHECK_PW

dn: uid=swissidapp,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SWISSIDAPP_PW

dn: uid=accountmanager,ou=people,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $ACCOUNTMGR_PW
EOF
}

init_swissid() {
    update_swissid_passwords
}
