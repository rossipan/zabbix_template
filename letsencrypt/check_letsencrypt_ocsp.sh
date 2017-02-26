#! /bin/sh
ZABBIX_CONFIG=/etc/zabbix/zabbix_agentd.conf
ZABBIX_SENDER=/usr/bin/zabbix_sender
RETVAL=0

if [ -z "$1" ]; then
  SERVER=127.0.0.1;
else
  SERVER=$1;
fi

if [ -z "$2" ]; then
  PORT=443;
else
  PORT=$2;
fi

echo "">/tmp/$SERVER.chain.pem
echo "">/tmp/$SERVER.site.pem

#Getting the SSL certificates expiry date
EXPIRE_DATE=`echo | openssl s_client -connect $SERVER:$PORT 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d'=' -f2`
EXPIRE_SECS=`date -d "${EXPIRE_DATE}" +%s`
EXPIRE_TIME=$(( ${EXPIRE_SECS} - `date +%s` ))
if test $EXPIRE_TIME -lt 0; then
  RETVAL=0
else
  RETVAL=$(( ${EXPIRE_TIME} / 24 / 3600 ))
fi

#Getting the certificate chain
openssl s_client -connect $SERVER:$PORT 2>&1 < /dev/null | sed -n '/-----BEGIN/,/-----END/p' >/tmp/$SERVER.site.pem
openssl s_client -connect $SERVER:$PORT -showcerts 2>&1 < /dev/null | sed -n '/ 1 s:/,/-----END/p' >/tmp/$SERVER.chain.pem

#Get a certificate with a OCSP URL
OCSP_URL=`openssl x509 -ocsp_uri -in /tmp/$SERVER.site.pem -noout`
OCSP_DOMAIN=`echo $OCSP_URL | sed -e 's/http:\/\///g' -e 's/.$//g'`

#Sending the OCSP request
VERIFY_OCSP_STATS=`openssl ocsp -header Host $OCSP_DOMAIN -no_nonce -issuer /tmp/$SERVER.chain.pem -cert /tmp/$SERVER.site.pem -url $OCSP_URL -noverify | grep "good" -wc`

#Send result to zabbix
echo "$SERVER:$PORT expires in $RETVAL days"
echo "OCSP_URL : $OCSP_URL"
echo "VERIFY_OCSP_STATS: $VERIFY_OCSP_STATS"
$ZABBIX_SENDER -c $ZABBIX_CONFIG -k ssl_cert_remaining -o "$RETVAL"
$ZABBIX_SENDER -c $ZABBIX_CONFIG -k ocsp_url -o "$OCSP_URL"
$ZABBIX_SENDER -c $ZABBIX_CONFIG -k verify_ocsp_stats -o "$VERIFY_OCSP_STATS"