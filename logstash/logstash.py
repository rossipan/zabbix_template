#!/usr/bin/env python

import urllib
import json
import sys, os, time

def main():
    # Usage: %s [url] path.counter.name
    # [url] ='all' by default
    urls = { 'indexer_node_stats_jvm'          : "http://localhost:9600/_node/stats/jvm",
             'indexer_node_stats_process'      : "http://localhost:9600/_node/stats/process",
             'indexer_node_stats_mem'          : "http://localhost:9600/_node/stats/mem",
             'indexer_node_stats_pipeline'     : "http://localhost:9600/_node/stats/pipeline",
             'shipper_node_stats_jvm'          : "http://localhost:9601/_node/stats/jvm",
             'shipper_node_stats_process'      : "http://localhost:9601/_node/stats/process",
             'shipper_node_stats_mem'          : "http://localhost:9601/_node/stats/mem",
             'shipper_node_stats_pipeline'     : "http://localhost:9601/_node/stats/pipeline" }
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
    tmp = '/tmp/logstash_stats_'+ty
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
      if ty == 'all':
        for node_id in body['nodes'].keys():
          if body['nodes'][node_id]['name'] == os.uname()[1]:
            stats = body['nodes'][node_id]
      else:
        stats = body

      #JVM counters calculations
      if cnt == 'jvm.mem.heap_committed_in_bytes':
        out = str(float(stats['jvm']['mem']['heap_committed_in_bytes'])/2)
      elif cnt == 'jvm.mem.heap_max_in_bytes':
        out = str(float(stats['jvm']['mem']['heap_max_in_bytes'])/2)
      elif cnt == 'jvm.mem.heap_used_in_bytes':
        out = str(float(stats['jvm']['mem']['heap_used_in_bytes'])/2)
      elif cnt == 'jvm.mem.non_heap_committed_in_bytes':
        out = str(float(stats['jvm']['mem']['non_heap_committed_in_bytes'])/2)
      elif cnt == 'jvm.mem.non_heap_used_in_bytes':
        out = str(float(stats['jvm']['mem']['non_heap_used_in_bytes'])/2)

      #direct value
      else:
        c=cnt.split('.')
        while len(c):
          stats=stats[c.pop(0)]
        out = str(stats)

    print out

if __name__ == "__main__":
    main()