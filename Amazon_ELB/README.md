## Cron job
```
  */5 * * * * /etc/zabbix/get_elb_status.sh getstate > /dev/null 2>&1
```
