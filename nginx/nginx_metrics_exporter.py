#!/usr/bin/env python
#coding: utf-8

from __future__ import division
import sys, os, re
import logging
import argparse
from subprocess import Popen, PIPE

def get_position(source_file):
    position_file = '/etc/zabbix/log.position'
    if not os.path.exists(source_file):
        print("No source_file is found at %s" % source_file)
        os._exit(1)

    #first access, position_file is null
    if not os.path.exists(position_file):
        start_position = str(0)
        end_position = str(os.path.getsize(source_file))
        fh = open(position_file,'w')
        fh.write('start_position: %s\n' % start_position)
        fh.write('end_position: %s\n' % end_position)
        fh.close()
        os._exit(1)
    else:
        fh = open(position_file)
        se = fh.readlines()
        fh.close()
        if len(se) != 2:
            os.remove(position_file)
            os._exit(1)
        last_start_position,last_end_position = [item.split(':')[1].strip() for item in se]
        start_position = last_end_position
        end_position = str(os.path.getsize(source_file))
        #log rotate, start_position > end_position

        if int(start_position) > int(end_position):
            start_position = 0
        #if log rotate is fail
        elif int(start_position) == int(end_position):
            os._exit(1)

        fh = open(position_file,'w')
        fh.write('start_position: %s\n' % start_position)
        fh.write('end_position: %s\n' % end_position)
        fh.close()
        return map(int,[start_position,end_position])

def summarize(start_position, end_position, source_file):
    log = open(source_file)
    log.seek(start_position,0)
    total_requests, total_request_time, total_upstream_response_time = 0, 0, 0

    #- 10.0.1.14 [08/Mar/2019:06:48:37 +0000][1552027717.314] "GET /version HTTP/1.1" 200 93 "-" "ELB-HealthChecker/2.0" "-" 0.001 0.001
    #'- $proxy_add_x_forwarded_for [$time_local][$msec]'
    #      ' "$request" $status $body_bytes_sent '
    #      '"$http_referer" "$http_user_agent" "$request_body" '
    #      '$request_time $upstream_response_time'
    log_format = re.compile(r"""^\- (?P<forwarded_for>[^"]*|\-) \[(?P<datetime>[0-9]{2}\/[A-Za-z]{3}\/[0-9]{1,4}:[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2} [+\-][0-9]{4})\]\[(?P<msec>[\d\.]+)\] "(?P<method>[A-Z ]+) (?P<uri>[^"]*) (?P<protocol>[^"]*)" (?P<status>[0-9]{3}) (?P<bytes>[0-9]{1,}|\-) "(?P<referer>[^"]*|\-)" "(?P<user_agent>[^"]+)" "(?P<request_body>[^"]*|\-)" (?P<request_time>[\d\.]+) (?P<upstream_response_time>[\d\.]+) .*$""")

    while True:
        current_position = log.tell()
        if current_position >= end_position:
            break
        line = log.readline()

        m = log_format.search(line)
        if m:
            total_request_time += float(m.group('request_time'))
            total_upstream_response_time += float(m.group('upstream_response_time'))
            total_requests += 1

    log.close()

    if total_requests > 1:
        avg_request_time = total_request_time / total_requests
        avg_upstream_response_time = total_upstream_response_time / total_requests
        _notify_zabbix('avg_request_time', avg_request_time)
        _notify_zabbix('avg_upstream_response_time', avg_upstream_response_time)

def _notify_zabbix(zabbix_key, zabbix_value):
    zabbix_sender = "/usr/bin/zabbix_sender"
    zabbix_config = "/etc/zabbix/zabbix_agentd.conf"
    if not os.path.exists(zabbix_sender):
        print("No zabbix_sender is found at %s, skip zabbix notification" % zabbix_sender)
        os._exit(1)

    if not os.path.exists(zabbix_config):
        print("No zabbix_config is found at %s, skip zabbix notification" % zabbix_config)
        os._exit(1)

    from subprocess import call
    print("%s -c %s -k \"%s\" -o \"%s\"") % (zabbix_sender, zabbix_config, zabbix_key, zabbix_value)
    call("%s -c %s -k \"%s\" -o \"%s\"" % (zabbix_sender, zabbix_config, zabbix_key, zabbix_value), shell=True)

def parse_args(argv):
    p = argparse.ArgumentParser(description="export metrics from nginx access log files to zabbix"
                                "limits")
    p.add_argument("-s", "--source_file", action="store",
                   dest='source_file',required='true',
                   help="Specifying a source file")
    args = p.parse_args(argv)
    return args

if __name__ == '__main__':
    logging.basicConfig(format='[%(asctime)s] [%(levelname)s] %(message)s',level=logging.INFO)
    args = parse_args(sys.argv[1:])

    start_position,end_position = get_position(args.source_file)
    summarize(start_position, end_position, args.source_file)
