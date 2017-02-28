#!/usr/bin/env python

import urllib
import json
import sys, os, time

def main():
    # Usage: %s [url] path.counter.name
    # [url] ='all' by default
    urls = { 'fs'      : "http://localhost:9200/_nodes/_local/stats/fs",
             'indices' : "http://localhost:9200/_nodes/_local/stats/indices",
             'jvm'     : "http://localhost:9200/_nodes/_local/stats/jvm",
             'health'  : "http://localhost:9200/_cluster/health" }
    if len(sys.argv) < 2:
      sys.exit('Usage: %s [url] path.counter.name' % sys.argv[0])

    #parse command line
    if len(sys.argv) > 2 and sys.argv[1] in urls:
      ty  = sys.argv[1]
      url = urls[ty]
      cnt = sys.argv[2]
    else:
      ty  = 'all'
      url = urls[ty]
      cnt = sys.argv[1]

    #download url with caching
    tmp = '/tmp/es_stats_'+ty
    try:
      if os.path.isfile(tmp) and (os.path.getmtime(tmp) + 30) > time.time():
        f = file(tmp,'r')
        body = json.load(f)
        f.close()
      else:
        f = urllib.urlopen(url)
        body = f.read()
        f = file(tmp,'w')
        f.write(body)
        f.close()
        body = json.loads(body)

    except:
      out = '0'

    else:
      #get results for current node from cluster results
      if ty != 'health':
        for node_id in body['nodes'].keys():
          if body['nodes'][node_id]['name'] == os.uname()[1]:
            stats = body['nodes'][node_id]
      else:
        stats = body

      #JVM counters calculations
      if cnt == 'fs.total.disk_reads':
        out = str(stats['fs']['io_stats']['total']['read_kilobytes'])
      elif cnt == 'fs.total.disk_writes':
        out = str(stats['fs']['io_stats']['total']['write_kilobytes']) 

      #direct value
      else:
        c=cnt.split('.')
        while len(c):
          stats=stats[c.pop(0)]
        out = str(stats)

    print out

if __name__ == "__main__":
    main()
