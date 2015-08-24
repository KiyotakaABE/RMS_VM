# -*- coding: utf-8 -*-

#
#        Control Groups class  [0.15.2012011801]
#
#  - Management cgroups more easily by agent program.
#
#  - Usage:
#       cg = Cgroups.new 'httpd'
#       cg.tasks pid # Set process to group
#       cg.cpu 512  # Set cpu to 512
#      # cg.mem 256  # Set memory to 256
#       cg.cpu      # Get current cpu assignment
#      # cg.mem      # Get current memory assignment
#       cg.cpuacct  # Get current cpu usage
#      # cg.memacct  # Get current memory usage
#

require_relative 'default'

class Cgroups
  # Is Control Groups already initialized or not?
  @@isinit = false

  # Associated application
  @app = nil

  # Constructor
  def initialize (app)
    if @@isinit == false
      check
      @@isinit = true
    end

    setup app
  end

  # Make resource controller
  def setup (app)
    d '* Checking application identifier'

    if ! app.is_a? String
      abort 'ERR (cgroups): Illegal application identifier is found.'
    end
    @app = app
    d "[ OK ] Application identifier is '#{@app.inspect}'"
    d '* Initializing resource controller'
    begin
      # ここをちょっと修正した
      if !(File.exist? "#{CGROUP}/#{@app}" and File.directory? "#{CGROUP}/#{@app}")
        Dir.mkdir "#{CGROUP}/#{@app}"
      end
    rescue
      abort "ERR (cgroups): Can't initialize cgroups resource controllers."
    end
    d '[ OK ] All of resource controllers is initialized correctly'
  end
    
  # Check Control Groups availability
  def check
    d '* Retrieving cgroups trails'

    k = `uname -r | cut -d '-' -f 1`.strip.split('.')
    k.map! {|v| v.to_i }

    if k[0] < 2 || k[0] == 2 && k[1] < 6 || k[0] == 2 && k[1] == 6 && k[2] < 24
      abort "ERR (cgroups): Kernel #{k.join('.')} does not supported cgroups (< 2.6.24)"
    end
    d "[ OK ] Kernel #{k.join('.')} supported cgroups (>= 2.6.24)"

    if `dmesg | grep cgroup`.strip.empty?
      d "[ NG ] Can't find cgroups trail from dmesg"
    else
      d '[ OK ] Find cgroups trail from dmesg'
    end
    if `grep cgroup /proc/mounts`.strip.empty?
      d "[ NG ] Can't find cgroups trail from /proc/mounts"
    else
      d '[ OK ] Find cgroups trail from /proc/mounts'
    end


    d '* Checking cgroups settings'

    if ! File.exist? CGROUP
      abort "ERR (cgroups): Control Groups directory (#{CGROUP.inspect}) is not exists."
    end
    if ! File.directory? CGROUP
      abort "ERR (cgroups): Control Groups directory (#{CGROUP.inspect}) is not a directory."
    end
    if ! File.writable_real? CGROUP
      abort "ERR (cgroups): Control Groups directory (#{CGROUP.inspect}) is not writable."
    end
    d '[ OK ] Control Groups directory is available and writable'

#    if ! File.exist? "#{CGROUP}/tasks"
#      abort 'ERR (cgroups): Control Groups VFS is not mounted.'
#    end
#    d '[ OK ] Control Groups VFS is mounted correctly'
  end
 
  # Read integer from Control Groups VFS
  def ri (p)
    return `cat #{p}`.strip.to_i
  end

  # Read integers from Control Groups VFS
  def ria (p)
    a = []
    `cat #{p}`.each_line {|l| a.push l.strip.to_i }
    return a
  end
 
  # Write to Control Groups VFS
  def w (p, v)
    `/bin/echo #{v} > #{p}`
  end

  # Append to Control Groups VFS
  def a (p, v)
    `/bin/echo #{v} >> #{p}`
  end

  # Manage cpu subsystems (CPU assignment)
  def cpu (c = nil)
    # 操作対象をcpu.sharesからcpu.cfs_quota_usに変更した
    # cg = "#{CGROUP}/#{@app}/cpu.shares"
    cg = "#{CGROUP}/#{@app}/cpu.cfs_quota_us"
   
    if c.nil?
      t = ri cg
      d "INFO (cgroups): Current cpu.shares is #{t.inspect}."
      return t # t : Raw value of 'cpu.shares'
    elsif c.is_a? Integer
      w(cg, c)

      if c == cpu
        d "INFO (cgroups): Successfully changing cpu.shares. Current value is #{c.inspect}."
        return true
      else
        d "INFO (cgroups): Failed to changing cpu.shares. Current value is #{cpu.inspect}."
        return false
      end
    else
      abort 'ERR (cgroups): Illegal usage of cpu method.'
    end
  end


  # Manage processes in Control Groups (Process ID assignment)
  def tasks (p = nil)
    cg = "#{CGROUP}/#{@app}/tasks"
    
    if p.nil?
      pids = ria cg
      d "INFO (cgroups): Current tasks is #{pids.inspect}."
      return pids # pids : Array of all process id(s) in resource controller
    elsif p.is_a? Integer
      d 'INFO (cgroups): Trying to change tasks.'
      a(cg, p)

      if ! tasks.index(p).nil?
        d 'INFO (cgroups): Successfully changing tasks.'
        return true
      else
        d 'INFO (cgroups): Failed to changing tasks.'
        return false
      end
    else
      abort 'ERR (cgroups): Illegal usage of tasks method.'
    end
  end

  # Manage processes in Control Groups (Process ID confirmation)
  def procs
    cg = "#{CGROUP}/#{@app}/cgroup.procs"
    tgids = ria cg
    d "INFO (cgroups): Current cgroup.procs is #{tgids.inspect}."
    return tgids # pids : Array of all process id(s) in resource controller
  end
end
