# -*- coding: utf-8 -*-
require 'socket'
require 'redis'
require_relative 'cgroups'
require_relative 'default'

#  - Application cgroups more easily by agent program.

#  - Usage:
#       App.new.exec
#       app.ruby "name" "port number" # in the shell
#
#       telnet localhost "port numver"
#       % GET CPU          # Get value of "#{CGROUP}/#{@app}/cpu.cfs_quota_us"
#       % SET CPU 50000    # Set 50000 to "#{CGROUP}/#{@app}/cpu.cfs_quota_us" 
#       % GET MEMORY  # Get total number of bytes allocated by Redis (Byte)
#       % SET MEM 32MB     # Set limit of memory used by Redis
#       % GET THROUGHPUT   # Get throughput of app

class App
  # contructor
  def initialize
    if ARGV == nil
      abort "ERR (app): Application name is not specified"
    end
    @cg = Cgroups.new(ARGV[0])
    @cg.tasks Process::pid

    # @redis = Redis.new # デフォルトのポートが使用される
    @redis = Redis.new(:host => "127.0.0.1", :port => PORT_REDIS)
    @redis.config("set", "maxmemory-policy", "allkeys-lru")  # 削除ポリシー
    @redis.set(0, 0)
    @redis.set(1, 1)
    d '[ OK ] App is initialized.'
  end
    
  def exec
    d '* Executing app'
    start_throughput
    start_listening
    start_fib
    # loop{}
  end

  # throughput測定を開始
  def start_throughput
    @count = 0
    @throughput = 0
    Thread.new do
      while true
        sleep(INTERVAL_THROUGHPUT)
        @throughput = @count / INTERVAL_THROUGHPUT
        @count = 0
        d "INFO (app): THROUGHPUT is #{@throughput}"
      end
    end
  end

  # ソケット通信を開始
  def start_listening
    port = ARGV[1].to_i
    if port == 0
      gate = TCPServer.open(PORT_LISTEN)
      d "INFO (app): Opening gate in using defalt port number => #{PORT_LISTEN}."
    else
      gate = TCPServer.open(port)
      d "INFO (app): Opening gate in using specified port number => #{PORT_LISTEN}."
    end
    Thread.new do
      @sock = gate.accept
      gate.close
      while true
        cmd = @sock.gets.chomp.split(" ")
        d "INFO (app): Recieved the command, and processing it. => #{cmd}."
        process_command(cmd)
      end
    end
  end

  # フィボナッチの計算を開始
  def start_fib
    while true
      # fibにあたえる引数は本番ではどうするか考える必要がある
      fib(rand(0..RANDMAX))
      @count += 1
    end
  end

  # fibonacci
  def fib(n)
    if n == 0
      return 0
    elsif n == 1
      return 1
    elsif (val = @redis.get(n)) != nil
      return val.to_i
    else
      val = fib(n-2) + fib(n-1)
      @redis.set(n, val)
      return val.to_i
    end
  end

  # クライアントへの出力
  def report_error(str)
    @sock.puts("ERRER: " + str)
    d "INFO (app): Sending ERRER message \"#{str}\" to client."
  end
  
  def report_result(str)
    @sock.puts(str)
    d "INFO (app): Sending message \"#{str}\" to client."
  end

  # コマンド処理 #
  def process_command(cmd)
    d "INFO (app): Processing command."
    case cmd[0]
    when /GET/i
      get_command(cmd)
    when /SET/i
      set_command(cmd)
    else
      report_error("Illegal command \"" + cmd[0] + "\"")
    end
  end

  def get_command(cmd)
    d "INFO (app): Processing \"GET\" command."
    if cmd.length < 2
      report_error("Number of args")
      return
    end
    case cmd[1]
    when /THROUGHPUT/i
      report_result(@throughput.to_s)
    when /MEMORY/i
      report_result(@redis.info["used_memory"]) # Byte
    when /CPU/i
      report_result(@cg.cpu.to_s)
    else
      report_error("Illegal argument \"" + cmd[1] + "\"")
    end
  end
  
  def set_command(cmd)
    if cmd.length < 3
      report_error("Num of args")
      return
    end
    case cmd[1]
    when /MEMORY/i
      if !maxmemory(cmd[2])
        report_error("Can't change MEMORY")
        return
      end
    when /CPU/i
      if cmd[2] == nil or cmd[2].to_i == 0
        report_error("Illegal argument \"" + cmd[2] + "\"")
        return
      else
        @cg.cpu(cmd[2].to_i)
      end
    end
    report_result("OK")
  end
  
  # メモリ操作 
  # 以下の書式でメモリ使用量の上限を指定 size
  # Note on units: when memory size is needed, it is possible to specify
  # it in the usual form of 1k 5GB 4M and so forth:
  #
  # 1k => 1000 bytes
  # 1kb => 1024 bytes
  # 1m => 1000000 bytes
  # 1mb => 1024*1024 bytes
  # 1g => 1000000000 bytes
  # 1gb => 1024*1024*1024 bytes
  #
  # units are case insensitive so 1GB 1Gb 1gB are all the same.

  # ちゃんと変更が完了してからreturnするようにする
  def maxmemory(size)
    d "INFO (app): Changing value of maxmemory. #{size}."
    ret = @redis.config("set", "maxmemory", size)
    if ret != "OK"
      d "[ NG ] Can't chage mexmemory. Return value is #{ret}."
      return false
    end
    return true
  end
end

App.new.exec
