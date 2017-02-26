#!/bin/bash
zabbix_config=/etc/zabbix/zabbix_agentd.conf;
zabbix_sender=/usr/bin/zabbix_sender;

## AWS Varible
Service=ELB
AWS=/usr/local/bin/aws
TempPath=/tmp
region="<aws region>"
AWS_ACCESS_KEY="<your aws access key>"
AWS_SECRET_KEY="<your aws secret key>"
AWS_ELB_URL="https://elasticloadbalancing.${region}.amazonaws.com"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}"
export JAVA_HOME=/usr/lib/jvm/jre-1.6.0-openjdk.x86_64
export AWS_ELB_HOME=/usr/local/ElasticLoadBalancing
PATH=$PATH:$HOME/bin:$JAVA_HOME/bin:$AWS_ELB_HOME/bin
export PATH

function discovery() {
    count=`wc -l < $TempPath/${Service}_list.tmp`
    a=0
    echo "{"
    echo "\"data\":["

    while [ $a -lt $count ]
    do
        read ELBname
        if [ $a -eq $(($count-1)) ]; then
                echo "{" \"{#LOADBALANCERNAME}\" : \"${ELBname}\" "}"
        else
                echo "{" \"{#LOADBALANCERNAME}\" : \"${ELBname}\" "},"
        fi
        a=$(($a+1))
    done < $TempPath/${Service}_list.tmp

    echo "]"
    echo "}"
}

function getstate() {
    $AWS  elb describe-load-balancers --region "$region" --output json |grep LoadBalancerName | awk '{print $2}' | sed -e 's/,$//' -e 's/"//g' >$TempPath/${Service}_list.tmp
    rm -f /tmp/${Service}_stat.data

    cat $TempPath/${Service}_list.tmp | while read ELBname; do

        elb-describe-instance-health $ELBname -I "${AWS_ACCESS_KEY}" -S "${AWS_SECRET_KEY}" -U ${AWS_ELB_URL} >$TempPath/${Service}_stat.tmp
        OutOfService=`grep -i OutOfService $TempPath/${Service}_stat.tmp -wc`
        INSTANCE=`grep -i INSTANCE_ID $TempPath/${Service}_stat.tmp -wc`
        if [ "$INSTANCE" -ge 1 ] && [ "$OutOfService" == "0" ]; then
                        echo - ELB.status[$ELBname] "1" >>$TempPath/${Service}_stat.data
        else
                        echo - ELB.status[$ELBname] "0" >>$TempPath/${Service}_stat.data
        fi
    done

    $zabbix_sender -c $zabbix_config -i /tmp/${Service}_stat.data -vv
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