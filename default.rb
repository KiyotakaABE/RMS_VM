# -*- coding: utf-8 -*-
# app.rb
PORT_LISTEN = 8000
PORT_REDIS = 6379
INTERVAL_THROUGHPUT = 10  # sec
RANDMAX = 10000

# cgroups.rb
# CGROUP = '/sys/fs/cgroup' 岡本さんのはこれだった
CGROUP = '/sys/fs/cgroup/cpu'

# Genaral settings
DEBUG = true

# Debug message output
#  - Usage: d('message', file)
def d (msg, file = nil)
  if DEBUG
    print Time.now.strftime('%H:%M:%S')
      #print Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    if ! file.nil?
      print " [#{File.basename(file, '.*').center(9)}]"
    end
    print ' : '
    puts msg
  end
end
