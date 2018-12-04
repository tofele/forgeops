#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0")/..; pwd)
source ${BATCH_DIR}/opendj/lib-header-opendj.sh

LDAPSEARCH=$binDir/ldapsearch
LOGS=${opendjExtractTargetPath}/logs
mkdir -p $LOGS

BASEDN=""

[ "$storeType" = "cts" ] && BASEDN="ou=famrecords,ou=openam-session,ou=tokens,$baseDN"
[ "$storeType" = "user" ] && BASEDN="ou=people,$baseDN"
[ "$storeType" = "config" ] && BASEDN="ou=default,ou=OrganizationConfig,ou=1.0,ou=AgentService,ou=services,o=sesam,ou=services,$baseDN"

# Note: Files in $LOGS are always overwritten below. Splunk will already have it picked up within a few seconds and then it is not required anymore.

if [ "$storeType" = "config" ]; 
then
	# Splunk temporary file to identify in a human readable form OAuth2 
	# clients.

	# filter OAuth2 clients for ou and com.forgerock.openam.oauth2provider.
	# description=[0] (client id description in DE).
	# Some values are in base64 and they are converted with GNU sed (e flag
	#  is not POSIX).
	# Multiline sed takes in pairs dn and sunKeyValue and transform it in:
	# client id desc-ou.
	# Output will be then adapted for splunk in this format:
	# 2018-03-15 10:52:29+01:00 client_id="IncaMail-baa7a-9895e-ae64c-9b4f4
	# " client_ou="baa7a-9895e-ae64c-9b4f4"
	# sed expects this format in input:
	# dn: ou=auto-relying-party-8c285df6a,ou=default,ou=OrganizationConfig,
	# ou=1.0,ou=AgentService,ou=services,o=sesam,ou=services,dc=swisssign,d
	# c=com
	# sunKeyValue: com.forgerock.openam.oauth2provider.description=[0]=de|D
	# E Auto created relying party

	IFS=$'\n'; 
	$LDAPSEARCH -h localhost -p $ldapsPort --useSSL --trustAll --bindDN "$rootUserDN" --bindPasswordFile $passwordFile --baseDN "$BASEDN" \
		--matchedValuesFilter "(sunKeyValue=com.forgerock.openam.oauth2provider.description=[0]*)" -s sub "(sunKeyValue=com.forgerock.openam.oauth2provider.description=*)" sunKeyValue| \
		sed -e 's/sunKeyValue:: \(.*\)/echo -n "sunKeyValue: "; echo \1|base64 -d/e' |grep -v '^$'| \
		sed '/dn/ {N; /sunKeyValue/ {s/dn: ou=\(.*\),ou=default.*\nsunKeyValue: com.forgerock.openam.oauth2provider.description.*|\(.*\)/\1;\2/;}}'| \
	        sed 's%\(.*\);\(.*\)%client_id=\\"\1\\" client_name=\\"\2\\"%'| \
		sed 's%\(.*\)%echo "$(date --rfc-3339='second') \1" %e'	> $LOGS/relyingparties
else
	# get total count of entries under $BASEDN
	TOTAL=$( $LDAPSEARCH -h localhost -p $ldapsPort --useSSL --trustAll --bindDN "$rootUserDN" --bindPasswordFile $passwordFile --baseDN "$BASEDN" -s base '(objectclass=*)' numsubordinates | grep numsubordinates | cut -d\  -f2 )
	echo "`date` $storeType entries=$TOTAL" > $LOGS/ldapentries

	# If this is not the userstore, we exit cleanly
	[ $storeType != "user" ] && exit 0

	# get total count of users with no RP consent
	NOCONSENT=$( $LDAPSEARCH -h localhost -p $ldapsPort --useSSL --trustAll --bindDN "$rootUserDN" --bindPasswordFile $passwordFile --baseDN "$BASEDN" -s sub '(!(oauth2SaveConsent=*))' dn: | grep "dn: uid=" | wc -l )
	echo "`date` consent client_id= count=$NOCONSENT" > $LOGS/consents

	# get all users with some RP consent
	$LDAPSEARCH -h localhost -p $ldapsPort --useSSL --trustAll --bindDN "$rootUserDN" --bindPasswordFile $passwordFile --baseDN "$BASEDN" -s sub '(oauth2SaveConsent=*)' oauth2SaveConsent | grep oauth2Save | cut -d\  -f2 > /tmp/consent

	# echo number of users with consent per RP
	for RP in $( cat /tmp/consent | sort -u )
	do
	    COUNT=$( $LDAPSEARCH -h localhost -p $ldapsPort --useSSL --trustAll --bindDN "$rootUserDN" --bindPasswordFile $passwordFile --baseDN "$BASEDN" -s sub "(oauth2SaveConsent=$RP *)" dn oauth2SaveConsent | grep dn: | wc -l )
	    echo "`date` consent client_id=$RP count=$COUNT" >> $LOGS/consents
	done

	# cleanup
	#rm -f /tmp/consent
fi
