#!/bin/sh
#set -x

ARCHIVE=/var/tmp/opendj.zip
SUPPORT_TOOL=/var/tmp/opendj-support-extract-tool.zip
SHARED=$PWD/shared

# CA_KEYSTORE=$SHARED/ca-keystore.p12
# CA_CERT=$SHARED/ca-cert.p12
# KEYSTORE_PIN=$SHARED/keystore.pin

SSL_CERT_ALIAS=server-cert
SSL_CERT_ALIAS=opendj-ssl
SSL_CERT_CN="CN=*.example.com,O=OpenDJ SSL"
CA_CERT_ALIAS=opendj-ca

PREFIX=${1}
PORT_DIGIT=${2}
SERVER_ID=${2}

JMX_PORT=${PORT_DIGIT}689
JMX_RMI_PORT=${PORT_DIGIT}699

WORKDIR=/var/tmp/ds

DJ=run/${1}${2}
DSHOST="${1}${2}.example.com"

#SECRETS=$DJ/secrets
SECRETS=/var/run/secrets/opendj

CA_KEYSTORE=$SECRETS/ca-keystore.p12
CA_CERT=$SECRETS/ca-cert.p12
KEYSTORE_PIN=$SECRETS/keystore.pin
SSL_KEYSTORE=$SECRETS/ssl-keystore.p12


clean()
{
    if [ -d $DJ ]; then
        $DJ/bin/stop-ds
        rm -rf $DJ
    fi
}

copy_secrets()
{
    mkdir -p /var/run/secrets/opendj
    cp secrets/* /var/run/secrets/opendj
}

create_keystores()
{
    if [ -d $SECRETS ]; then
        echo "Keystores exists - skipping"
        return
    fi

    mkdir -p $SECRETS
    cp $SHARED/* $SECRETS

    # Create SSL key pair and sign with the CA cert

    echo "password" > $KEYSTORE_PIN

    echo "Creating SSL key pair..."

    #cp $CA_CERT $SSL_KEYSTORE

    keytool -keystore $SSL_KEYSTORE \
            -storetype PKCS12 \
            -storepass:file $KEYSTORE_PIN \
            -genkeypair \
            -alias $SSL_CERT_ALIAS \
            -keyalg RSA \
            -dname "$SSL_CERT_CN" \
            -keypass:file $KEYSTORE_PIN

    keytool -keystore $SSL_KEYSTORE \
            -storetype PKCS12 \
            -storepass:file $KEYSTORE_PIN \
            -certreq \
            -alias $SSL_CERT_ALIAS | \
            \
    keytool -keystore $CA_KEYSTORE \
            -storetype PKCS12 \
            -storepass:file $KEYSTORE_PIN \
            -gencert \
            -alias $CA_CERT_ALIAS | \
            \
    keytool -keystore $SSL_KEYSTORE \
            -storetype PKCS12 \
            -storepass:file $KEYSTORE_PIN \
            -importcert \
            -alias $SSL_CERT_ALIAS
}

customize_setup_profile() {
  TARGET=opendj/template/setup-profiles/AM/identity-store/6.5/profile.groovy
  sed -e "s/ou=identities/${BASE_DN}/g" $TARGET > /tmp/profile.groovy
  chmod 644 $TARGET
  mv /tmp/profile.groovy $TARGET
  chmod 444 $TARGET

  TARGET=opendj/template/setup-profiles/AM/identity-store/6.5/base-entries.ldif
  chmod 644 $TARGET
  cp -p base-entries-is.ldif $TARGET
  chmod 444 $TARGET

#  TARGET=opendj/template/setup-profiles/AM/cts/6.5/profile.groovy
#  sed -e "s/ou=tokens/${BASE_DN}/g" $TARGET > /tmp/profile.groovy
#  chmod 644 $TARGET
#  mv /tmp/profile.groovy $TARGET
#  chmod 444 $TARGET

#  TARGET=opendj/template/setup-profiles/AM/cts/6.5/base-entries.ldif
#  chmod 644 $TARGET
#  cp -p base-entries-cts.ldif $TARGET
#  chmod 444 $TARGET
}

prepare()
{
    clean
    copy_secrets
    #create_keystores
    unzip -q $ARCHIVE
    customize_setup_profile
    unzip -q $SUPPORT_TOOL
    mkdir -p run
    mv opendj $DJ
    mv opendj-support-extract-tool $DJ/opendj
}

configure()
{
    echo "Adding system account to admin backend..."
    ADMIN_BACKEND=db/adminRoot/admin-backend.ldif
    ADMIN_BACKEND_TMP=db/adminRoot/admin-backend.ldif.tmp
    ./bin/ldifmodify $ADMIN_BACKEND > $ADMIN_BACKEND_TMP << EOF
dn: cn=OpenDJ,cn=Administrators,cn=admin data
changetype: add
objectClass: top
objectClass: applicationProcess
objectClass: ds-certificate-user
cn: OpenDJ
ds-certificate-subject-dn: CN=*.example.com,O=OpenDJ SSL
ds-privilege-name: config-read
ds-privilege-name: proxied-auth
EOF

    rm $ADMIN_BACKEND
    cp $ADMIN_BACKEND_TMP $ADMIN_BACKEND

    echo "Configuring Server ID..."
    ./bin/dsconfig set-global-configuration-prop \
          --set "server-id:${SERVER_ID}" \
          --offline \
          --no-prompt

    echo "Configuring Subject DN to User Attribute certificate mapper..."
    ./bin/dsconfig set-certificate-mapper-prop \
          --mapper-name "Subject DN to User Attribute" \
          --set "user-base-dn:cn=admin data" \
          --offline \
          --no-prompt

    echo "Configuring SASL/EXTERNAL mechanism handler certificate mapper..."
    ./bin/dsconfig set-sasl-mechanism-handler-prop \
          --handler-name EXTERNAL \
          --set "certificate-mapper:Subject DN to User Attribute" \
          --offline \
          --no-prompt

#    echo "Enabling LDIF audit logger..."
#    ./bin/dsconfig set-log-publisher-prop \
#          --publisher-name "File-Based Audit Logger" \
#          --set suppress-internal-operations:false \
#          --set enabled:true \
#          --offline \
#          --no-prompt

    echo "Enabling legacy LDAP access logger..."
    ./bin/dsconfig set-log-publisher-prop \
          --publisher-name "File-Based Access Logger" \
          --set enabled:true \
          --offline \
          --no-prompt

    echo "Disabling JSON LDAP access logger..."
    ./bin/dsconfig set-log-publisher-prop \
          --publisher-name "Json File-Based Access Logger" \
          --set enabled:false \
          --offline \
          --no-prompt

    echo "Setting combined log format..."
    ./bin/dsconfig set-log-publisher-prop \
          --publisher-name 'File-Based Access Logger' \
          --set log-format:combined \
          --offline \
          --no-prompt

    echo "Setting SMTP server to localhost..."
    ./bin/dsconfig set-global-configuration-prop \
          --set smtp-server:localhost \
          --offline \
          --no-prompt

    # still required for AM 6.5 ???
    echo "Setting default password policy..."
    ./bin/dsconfig set-password-policy-prop \
          --policy-name "Default Password Policy" --set "default-password-storage-scheme:Salted SHA-256" \
          --offline \
          --no-prompt

    # still required for AM 6.5 ???
    echo "Enabling UID unique attribute..."
    ./bin/dsconfig set-plugin-prop \
          --plugin-name "UID Unique Attribute" \
          --set base-dn:ou=people,$BASE_DN \
          --set enabled:true \
          --offline \
          --no-prompt

    echo "Creating JMX connection handler..."
    ./bin/dsconfig create-connection-handler \
          --handler-name "JMX Connection Handler" \
          --type jmx \
          --set enabled:true \
          --set listen-port:$JMX_PORT \
          --set rmi-port:$JMX_RMI_PORT \
          --set use-ssl:true \
          --set key-manager-provider:"Default Key Manager" \
          --set ssl-cert-nickname:$SSL_CERT_ALIAS \
          --offline \
          --no-prompt

    # Very verbose
    # echo "Enable debug logging"
    # ./bin/dsconfig set-log-publisher-prop \
    #       --publisher-name File-Based\ Debug\ Logger \
    #       --set enabled:true \
    #       --offline \
    #       --no-prompt

}

create_backend() {
    BACKEND=${1}

    echo "Creating ${BACKEND} backend..."
    ./bin/dsconfig \
          create-backend \
          --backend-name ${BACKEND} \
          --type je \
          --set enabled:true \
          --set base-dn:${BASE_DN} \
          --offline \
          --no-prompt

    echo "Checking ${BACKEND} backend..."
    ./bin/dsconfig \
          get-backend-prop \
          --backend-name ${BACKEND} \
          --offline \
          --no-prompt
}

post_config() {
    # still required for AM 6.5 ???
    # moved here because of the following error if done before start-ds in offline mode
    # msg=An error occurred while attempting to initialize an instance of class org.opends.server.plugins.UniqueAttributePlugin as a Directory Server plugin using the information in configuration entry cn=Email Unique Attribute,cn=Plugins,cn=config: ConfigException: The unique attribute plugin defined in configuration entry cn=Email Unique Attribute,cn=Plugins,cn=config is configured to operate on attribute mail but there is no equality index defined for this attribute in backend amIdentityStore (UniqueAttributePlugin.java:126 UniqueAttributePlugin.java:88 PluginConfigManager.java:356 PluginConfigManager.java:317 DirectoryServer.java:1361 DirectoryServer.java:4015). This plugin will be disabled

    echo "Enabling Email unique attribute..."
    ./bin/dsconfig create-plugin \
          --plugin-name "Email Unique Attribute" \
          --type unique-attribute \
          --set type:mail \
          --set base-dn:ou=people,$BASE_DN \
          --set enabled:true \
          --hostname ${DSHOST} \
          --port ${PORT_DIGIT}389 \
          --bindDN "cn=Directory Manager" \
          --bindPassword password \
          --no-prompt

    # fails with an ASN.1 error "Cannot decode the provided ASN.1 integer element because the length of the element value was not between one and four bytes (actual length was 0)"
    tail logs/access
}

load_ldifs() {
    # We only import the ldif on server 1 since we are going to initialize replication from it anyway.
    if [ "${PORT_DIGIT}" = "1" ];then
        STORES="configstore cts userstore"
        for STORE in $STORES
        do
  	       for file in ../../ldif/$STORE/*.ldif
  	        do
  	           echo "Loading ${file}"
               # search + replace all placeholder variables. Naming conventions are from AM.
              sed -e "s/@BASE_DN@/$BASE_DN/"  <${file}  >/tmp/file.ldif
              bin/ldapmodify -D "cn=Directory Manager"  --continueOnError -h ${DSHOST} -p ${PORT_DIGIT}389 -w password /tmp/file.ldif
            done
        done
    fi
}

post_start() {
    load_ldifs
    post_config
    build_indexes amIdentityStore
}

build_indexes() {
    BACKEND=${1}

    for file in ../../ldif/userstore/*.index; do
        echo "Building userstore indexes from ${file}"
        # search + replace all placeholder variables. Naming conventions are from AM.
        sed -e "s/@BACKEND@/$BACKEND/" <${file} >/tmp/file.index
        cat /tmp/file.index
        ./bin/dsconfig --batchFilePath /tmp/file.index --no-prompt
    done

#    echo "Rebuilding all indexes..."
#    ./bin/rebuild-index \
#          --hostname ${DSHOST} \
#          --port ${PORT_DIGIT}389 \
#          --bindDN "cn=Directory Manager" \
#          --bindPassword password \
#          --baseDN "${BASE_DN}" \
#          --rebuildAll \
#          --start 0 \
#          --no-prompt
}
