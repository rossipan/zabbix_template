export metrics from nginx access log files to zabbix
===

## Cron job
```
  */1 * * * * /etc/zabbix/nginx_metrics_exporter.py -s /var/log/nginx/access.log > /dev/null 2>&1
```
