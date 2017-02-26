#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ZABBIX_CONFIG=/etc/zabbix/zabbix_agentd.conf;
ZABBIX_SENDER=/usr/bin/zabbix_sender;
ZABBIX_EXTERNAL_SCRIPTS=/usr/lib/zabbix/externalscripts
PHANTOMJS_HOME=/opt/phantomjs
TEMP_PATH=/tmp

function discovery() {
    count=`wc -l < ${ZABBIX_EXTERNAL_SCRIPTS}/site_list.conf`
    a=0
    echo "{"
    echo "\"data\":["

    while [ $a -lt $count ]
    do
        read SITE_URL
        if [ $a -eq $(($count-1)) ]; then
                echo "{" \"{#SITE}\" : \"${SITE_URL}\" "}"
        else
                echo "{" \"{#SITE}\" : \"${SITE_URL}\" "},"
        fi
        a=$(($a+1))
    done < ${ZABBIX_EXTERNAL_SCRIPTS}/site_list.conf

    echo "]"
    echo "}"
}

function getstate() {
    rm -f $TEMP_PATH/site_stat.data

    cat ${ZABBIX_EXTERNAL_SCRIPTS}/site_list.conf | while read SITE_URL; do
        rm -f $TEMP_PATH/site_stat.tmp
        $PHANTOMJS_HOME/bin/phantomjs ${ZABBIX_EXTERNAL_SCRIPTS}/load.js "${SITE_URL}" >$TEMP_PATH/site_stat.tmp
        RESOURCE_ERROR=`grep "^#ResourceError" $TEMP_PATH/site_stat.tmp | awk -F":" '{print $2}'`
        JS_EXECUTION=`grep "^#JavaScriptExecution:True" $TEMP_PATH/site_stat.tmp -wc`
        URL_ERROR=`grep "^#FAIL to load the address" $TEMP_PATH/site_stat.tmp -wc`

        echo - SITE.status[\"${SITE_URL}\",RESOURCE_ERROR] "$RESOURCE_ERROR" >>$TEMP_PATH/site_stat.data
        echo - SITE.status[\"${SITE_URL}\",JS_EXECUTION] "$JS_EXECUTION" >>$TEMP_PATH/site_stat.data
        echo - SITE.status[\"${SITE_URL}\",URL_ERROR] "$URL_ERROR" >>$TEMP_PATH/site_stat.data

    done

    /usr/local/bin/casperjs test ${ZABBIX_EXTERNAL_SCRIPTS}/login_auth.js >$TEMP_PATH/auth_login_stat.tmp
    LOGIN_AUTH_NO_DUBIOS=`cat /tmp/auth_login_stat.tmp |grep "tests executed in" | grep "0 dubious" -wc`
    LOGIN_AUTH_NO_FAILED=`cat /tmp/auth_login_stat.tmp |grep "tests executed in" | grep "0 failed" -wc`
    LOGIN_AUTH_RESOURCE_ERROR=`cat /tmp/auth_login_stat.tmp |grep "ResourceError" -wc`

    if [ "$LOGIN_AUTH_NO_DUBIOS" == "1" ] && [ "$LOGIN_AUTH_NO_FAILED" == "1" ] && [ "$LOGIN_AUTH_RESOURCE_ERROR" == "0" ]; then
        echo - SITE.status[\"account_center\",CASPERJS_TEST_ERROR] "0" >>$TEMP_PATH/site_stat.data
    else
        echo - SITE.status[\"account_center\",CASPERJS_TEST_ERROR] "1" >>$TEMP_PATH/site_stat.data
    fi

    /usr/local/bin/casperjs test ${ZABBIX_EXTERNAL_SCRIPTS}/login_portal.js >$TEMP_PATH/portal_login_stat.tmp
    LOGIN_PORTAL_NO_DUBIOS=`cat /tmp/portal_login_stat.tmp |grep "tests executed in" | grep "0 dubious" -wc`
    LOGIN_PORTAL_NO_FAILED=`cat /tmp/portal_login_stat.tmp |grep "tests executed in" | grep "0 failed" -wc`
    LOGIN_PORTAL_RESOURCE_ERROR=`cat /tmp/portal_login_stat.tmp |grep "ResourceError" -wc`
    LOGIN_PORTAL_JS_ERROR=`cat /tmp/portal_login_stat.tmp |grep "JavaScriptExecution" -wc`

    if [ "$LOGIN_PORTAL_NO_DUBIOS" == "1" ] && [ "$LOGIN_PORTAL_NO_FAILED" == "1" ] && [ "$LOGIN_PORTAL_RESOURCE_ERROR" == "0" ] && [ "$LOGIN_PORTAL_JS_ERROR" == "0" ]; then
        echo - SITE.status[\"portal\",CASPERJS_TEST_ERROR] "0" >>$TEMP_PATH/site_stat.data
    else
        echo - SITE.status[\"portal\",CASPERJS_TEST_ERROR] "1" >>$TEMP_PATH/site_stat.data
    fi

    $ZABBIX_SENDER -c $ZABBIX_CONFIG -i $TEMP_PATH/site_stat.data -vv
}

case "$1" in
  discovery)
        discovery
        ;;
  getstate)
        getstate
        ;;
  *)
        echo $"Usage: $0 {discovery|getstate}"
        exit 1
esac