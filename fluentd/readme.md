# 1. intro

项目地址：[fluentd](https://github.com/fluent/fluentd?source=c)

项目官网：[http://fluentd.org/](http://fluentd.org/)

项目描述：一个ruby编写的日志搜集系统。Log Everything in JSON

fluentd是最近在使用的一个日志收集系统，它可以很方便的为其编写不同的输入输出插件，并且已经有了很多支持：[plugin](http://fluentd.org/plugin/)。因为工作中经常使用ruby，所以便对其源码产生了兴趣，我将对其进行一步步细致的分析学习，以加深对ruby的理解和更好的使用它。

READ THE * SOURCE CODE.

整个项目路径如下：

```
AUTHORS         Gemfile         bin             fluentd.gemspec
COPYING         README.rdoc     conf            lib
ChangeLog       Rakefile        fluent.conf     test
```

# 2. 可执行文件(bin)

## 2.1 fluent-cat

fluent-cat是fluentd的一个客户端，它通过标准输入给fluentd发送消息，github上的readme已经演示过了。

```
#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'rubygems' unless defined?(gem)
here = File.dirname(__FILE__)
$LOAD_PATH << File.expand_path(File.join(here, '..', 'lib'))
require 'fluent/command/cat'
```

`$LOAD_PATH`指的是Ruby读取外部文件的一个环境变量，其实和windows的环境变量是一个概念。Ruby会在这个环境变量的路径中读取需要require的文件，如果在环境变量中找不到自己想要的文件，就会报LoadError错误。`$LOAD_PATH`也可写作`$:`。

`__FILE__` 指的是当前rb文件所在目录的相对位置。

File.join是把自己的参数组成一个目录形式的方法

所以上面的代码假定了你会在fluentd路径下执行，并且将lib文件夹增加到环境变量以便于require里面的fluent代码。

于是找到lib/fluntd/command/cat文件.

## 2.2 fluent/command/cat

[代码链接](https://github.com/fluent/fluentd/blob/master/lib/fluent/command/cat.rb)
[OptionParser.html](http://ruby-doc.org/stdlib-2.0/libdoc/optparse/rdoc/OptionParser.html)

```
require 'optparse'
require 'fluent/env'

op = OptionParser.new
```
optparse是解析ruby命令行代码的库，当然还有其他库，不过没有optparse做的好:

使用以下代码添加不同的参数解析:

```
op.on('-p', '--port PORT', "test tcp port (default #{port})", Integer) { |i|
  port = i
}
```

使用`op.to_s`产生 usage 字符串，下面的代码在当前作用于产生了一个usage函数:

```
(class<<self;self;end).module_eval do
  define_method(:usage) do |msg|
    puts op.to_s
    puts "error: #{msg}" if msg
    exit 1
  end
end
```
直接定义一个`def usage`函数不能够使用到外部的`op`变量，而这种动态编程方法可以，称为作用域扁平化，这样可以避免把op定义为全局变量，是ruby中很常见的编程trick。

```
begin
  op.parse!(ARGV)

  if ARGV.length != 1
    usage nil
  end

  tag = ARGV.shift

rescue
  usage $!.to_s
end
```

`ARGV` 是ruby程序使用的参数的常量数组。而`$!`是一个ruby默认的全局变量：

* $! 最近一次的错误信息
* $@ 错误产生的位置
* $_ gets最近读的字符串
* $. 解释器最近读的行数(line number)
* $& 最近一次与正则表达式匹配的字符串
* $~ 作为子表达式组的最近一次匹配
* $n 最近匹配的第n个子表达式(和$~[n]一样)
* $= 是否区别大小写的标志
* $/ 输入记录分隔符
* $\ 输出记录分隔符
* $0 Ruby脚本的文件名
* $* 命令行参数
* $$ 解释器进程ID
* $? 最近一次执行的子进程退出状态

这里有篇 [demo](http://www.cnblogs.com/lwm-1988/archive/2012/04/19/2456932.html)。

下面require了若干个库:

```
require 'thread'
require 'monitor'
require 'socket'
require 'yajl'
require 'msgpack'
```

### 2.2.1 thread

Ruby的多线程编程库，先学习一下其基本用法：

[thread](https://github.com/zhuoyikang/rtfsc/blob/master/fluentd/thread_tr.rb)

```
require 'thread'
require 'net/http'
pages = %w(www.iteye.com www.csdn.net www.sina.com.cn www.google.cn)
threads = []

for page in pages
  threads << Thread.new(page) do |url|
    h = Net::HTTP.new(url, 80)
    puts "The URL is #{url} #{h}"
    resp = h.get('/')
    puts "The #{url} response:#{resp.message}"
  end
end

threads.each { |t|t.join  }
```
Ruby中使用的线程是用户级线程，由Ruby解释器进行切换管理。其效率要低于由OS管理线程的效率，且不能使用多个CPU。

[官方文档](http://ruby-doc.org/core-2.0/Thread.html)

### 2.2.2 线程同步

有线程就有线程同步机制：

[*Mutex*](https://github.com/zhuoyikang/rtfsc/blob/master/fluentd/mutex_tr.rb)

Mutex是mutual-exclusion lock（互斥锁）的简称。若对Mutex加锁时发现已经处于锁定状态时，线程会挂起直到解锁为止。

在并行访问中保护共享数据时，可以使用下列代码（m是Mutex的实例）

```
begin
   m.lock
   # 访问受m保护的共享数据
ensure
   m.unlock
end
```

Mutex有个synchronize方法可以简化这一过程。

```
m.synchronize {
   # 访问受m保护的共享数据
}
```

[*Queue*](https://github.com/zhuoyikang/rtfsc/blob/master/fluentd/queue_tr.rb)

Queue就像一条读写数据的管道。提供数据的线程在一边写入数据，而读取数据的线程则在另一边读出数据。若Queue中没有可供读取的数据时，读取数据的线程会挂起等待数据的到来。

```
require 'thread'

q = Queue.new

(1..10).each do
  Thread.new {
    while line = q.pop
      print "#{Thread.current} #{line}"
    end
  }
end

while (u = gets)
  q.push(u)
end
```
当你输入字符串的时候，可以看到每次`Thread.current`都不一样，放心Queue是线程安全的.

[*Monitor*](https://github.com/zhuoyikang/rtfsc/blob/master/fluentd/monitor_tr.rb)

monitor和mutex最大的区别是mutx不可以嵌套，但monitor可以。

```
require 'monitor'

#和mutex一样的用法，但是嵌套没有问题.
lock = Monitor.new
lock.synchronize do
  lock.synchronize do
    puts "nce"
  end
end
```

可以通过继承monitor获取其synchronize方法：

```
class Counter < Mutex
  attr_reader :number
  def initialize
    @number = 0
    super # 初始化父类数据
  end

  def plus
    synchronize do
      @number += 1
    end
  end
end

c = Counter.new
t1 = Thread.new { 10000.times { c.plus } }
t2 = Thread.new { 10000.times { c.plus } }
t1.join
t2.join
puts c.number
```

或者将其mixin:

```
class Counter
    include MonitorMixin
	…
end
```

以上内容基本就是ruby的线程同步机制了，现在看fluentd:

### 2.2.3 writer

Writer mixin Monitor，而TimerThread是一个简单的定时器实现。

```
class Writer
  include MonitorMixin

   class TimerThread
    def initialize(writer)
      @writer = writer
    end

	# 以TimerThread的run方法开始一个线程，而已。
    def start
      @finish = false
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @finish = true
      @thread.join
    end

    def run
      until @finish
        sleep 1
        @writer.on_timer
      end
    end

end
```
[MessagePack](http://msgpack.org/) 是一种高性能的二进制序列化格式，它可以让你在多种不同的语言之间交换数据，其支持的语言非常多，也非常成熟，是一种跨语言的基于二进制的数据格式。从官方的介绍来看，它能够比google protocol buffers快4倍，比json快10倍多。

```
Ruby Python Perl C/C++ Java Scala PHP
Lua JavaScript Node.js Haskell C#
Objective-C Erlang D OCaml Go LabVIEW Smalltalk

"Fluentd uses MessagePack for all internal data representation. It's crazy fast because of zero-copy optimization of msgpack-ruby. Now MessagePack is an essential component of Fluentd to achieve high performance and flexibility at the same time."

Sadayuki Furuhashi, creator of Fluentd.
```
或许MessagePack也可以用作游戏通信协议，可以再深入评定一下。

与JSON的比较

1.序列化和反序列化所需要的时间少。通过30000条的记录来测试，msgpack序列化的时间比使用json来序列化JSON的时间要少三分之一；而反序列化的时间则要少一半。

2.生成的文件体积小。同样也是基于30000条记录来测试，msgpack序列化后生成的二进制文件比用json序列化出来的时间要少一半。

[Yajl](https://github.com/brianmario/yajl-ruby) :A streaming JSON parsing and encoding library for Ruby (C bindings to yajl)

[yajl-ruby doc](http://rdoc.info/github/brianmario/yajl-ruby)

```
JSON parsing and encoding directly to and from an IO stream (file, socket, etc) or String. Compressed stream parsing and encoding supported for Bzip2, Gzip and Deflate.
Parse and encode multiple JSON objects to and from streams or strings continuously.
JSON gem compatibility API - allows yajl-ruby to be used as a drop-in replacement for the JSON gem
Basic HTTP client (only GET requests supported for now) which parses JSON directly off the response body *as it's being received*
~3.5x faster than JSON.generate
~1.9x faster than JSON.parse
~4.5x faster than YAML.load
~377.5x faster than YAML.dump
~1.5x faster than Marshal.load
~2x faster than Marshal.dump
```

这个只是为了展示内容用的，序列化格式还是msgpack。

```
def get_socket
    unless @socket
      unless try_connect
        return nil
      end
    end

    @socket_time = Time.now.to_i
    return @socket
  end
```

整个cat命令是通过socket和fluentd进程通信，也就是它是一个fluentd的客户端，所以有一堆处理连接的代码，包括try_connect函数。

真正的将数据写入连接是在函数:

```
def write_impl(array)
    socket = get_socket
    unless socket
      return false
    end

    begin
      socket.write [@tag, array].to_msgpack
      socket.flush
    rescue
      $stderr.puts "write failed: #{$!}"
      close
      return false
    end

    return true
  end
```
接下来的代码将获取标准输入，将其发送到fluentd了：

```
case format
when 'json'
  begin
    while line = $stdin.gets
      record = Yajl.load(line)
      w.write(record)
    end
  rescue
    $stderr.puts $!
    exit 1
  end
```

默认的fluentd的配置在env中获得`require 'fluent /env'`。

由于ThreadTimer，Writer对象的on_timer方法会被1s间隔的调用，每次调用会将@pending数组的数据尝试写到服务器。如果写入失败，则将其放入pending队列，等到1秒钟后下一次定时调用时将其写入。


以上内容就是cat命令。


## 2.3 fluentd

和cat一样，bin/fluentd对应于lib/fluentd/command/fluentd.rb。

开始的部分和cat一样，通过OptionParser解析命令行参数:

```
op = OptionParser.new
op.version = Fluent::VERSION

# default values
opts = {
  :config_path => Fluent::DEFAULT_CONFIG_PATH,
  :plugin_dirs => [Fluent::DEFAULT_PLUGIN_DIR],
  :log_level => Fluent::Log::LEVEL_INFO,
  :log_path => nil,
  :daemonize => false,
  :libs => [],
  :setup_path => nil,
  :chuser => nil,
  :chgroup => nil,
  :suppress_interval => 0,
}

op.on('-s', "--setup [DIR=#{File.dirname(Fluent::DEFAULT_CONFIG_PATH)}]", "install sample configuration file to the directory") {|s|
  opts[:setup_path] = s || File.dirname(Fluent::DEFAULT_CONFIG_PATH)
}
```

`Fluent::VERSION`在[version.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/version.rb)中定义，可以看出整个Fluentd的代码被包含在了 module Fluent中，它起到了命名空间的作用:

```
module Fluent

VERSION = '0.10.36'

end
```

在[env.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/env.rb)中定义了一系列的配置参数:

```
module Fluent
DEFAULT_CONFIG_PATH = ENV['FLUENT_CONF'] || '/etc/fluent/fluent.conf'
DEFAULT_PLUGIN_DIR = ENV['FLUENT_PLUGIN'] || '/etc/fluent/plugin'
DEFAULT_SOCKET_PATH = ENV['FLUENT_SOCKET'] || '/var/run/fluent/fluent.sock'
DEFAULT_LISTEN_PORT = 24224
DEFAULT_FILE_PERMISSION = 0644
end
```

接下来这段代码在安装路径建立plugin文件夹和fluentd.conf配置文件:

```
if setup_path = opts[:setup_path]
  require 'fileutils'
  FileUtils.mkdir_p File.join(setup_path, "plugin")
  confpath = File.join(setup_path, "fluent.conf")
  if File.exist?(confpath)
    puts "#{confpath} already exists."
  else
    File.open(confpath, "w") {|f|
      conf = File.read File.join(File.dirname(__FILE__), "..", "..", "..", "fluent.conf")
      f.write conf
    }
    puts "Installed #{confpath}."
  end
  exit 0
end
```

最后加载supervisor(监督者)模块，进行fluentd程序启动。

```
require 'fluent/supervisor'
Fluent::Supervisor.new(opts).start
```
# 3.监督者(Supervisor)

监督者是这样一个概念，它对程序中的工作者起监督作用，当其异常退出或者状态异常时对其进行重启，fluentd的监督者在[supervisor.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/supervisor.rb)中定义：

```
class Supervisor
  class LoggerInitializer
    def initialize(path, level, chuser, chgroup)
      @path = path
      @level = level
      @chuser = chuser
      @chgroup = chgroup
    end
 ...
```
内部定义了一个LoggerInitializer类，输出文件的路径定义哎path变量中，如果没有者使用标准输出。在Supervisor中的init函数修改了输出日志文件的权限:

```
  if @path && @path != "-"
        @io = File.open(@path, "a")
        if @chuser || @chgroup
          chuid = @chuser ? `id -u #{@chuser}`.to_i : nil
          chgid = @chgroup ? `id -g #{@chgroup}`.to_i : nil
          File.chown(chuid, chgid, @path)
        end
      else
        @io = STDOUT
      end

    $log = Fluent::Log.new(@io, @level)   # 开启一个Log实例
    $log.enable_color(false) if @path   # 开启颜色
    $log.enable_debug if @level <= Fluent::Log::LEVEL_DEBUG

```

linux id 命令:

    -g或--group 　显示用户所属群组的ID。
    -G或--groups 　显示用户所属附加群组的ID。
    -n或--name 　显示用户，所属群组或附加群组的名称。
    -r或--real 　显示实际ID。
    -u或--user 　显示用户ID。

而File.chown函数是改变文件所属的用户和组，只有超级用户才有权限改变一个文件所属的用户和组。这个文件的所有者可以把该文件的组改为其所有者所在的任意组。

Supervisor的initialize主要是开启了一个Log模块，使用了在OptionParser的参数:

```
 def initialize(opt)
    @config_path = opt[:config_path]
    @log_path = opt[:log_path]
    @log_level = opt[:log_level]
    @daemonize = opt[:daemonize]
    @chgroup = opt[:chgroup]
    @chuser = opt[:chuser]
    @libs = opt[:libs]
    @plugin_dirs = opt[:plugin_dirs]
    @inline_config = opt[:inline_config]
    @suppress_interval = opt[:suppress_interval]
    @dry_run = opt[:dry_run]

    @log = LoggerInitializer.new(@log_path, @log_level, @chuser, @chgroup)
    @finished = false
    @main_pid = nil
  end

```
## 3.1 Fluent::Log模块

Log模块提供颜色输出。

```
  module TTYColor
    RESET   = "\033]R"
    CRE     = "\033[K"
    CLEAR   = "\033c"
    NORMAL  = "\033[0;39m"
    RED     = "\033[1;31m"
    GREEN   = "\033[1;32m"
    YELLOW  = "\033[1;33m"
    BLUE    = "\033[1;34m"
    MAGENTA = "\033[1;35m"
    CYAN    = "\033[1;36m"
    WHITE   = "\033[1;37m"
  end
```

在终端上输出控制字符可以输出有颜色的字符串，比如你试试：`noglob echo "\033[1;34mthis is blues\033]R"`，就有颜色了。

以下是各种日志等级:
```
LEVEL_TRACE = 0
LEVEL_DEBUG = 1
LEVEL_INFO  = 2
LEVEL_WARN  = 3
LEVEL_ERROR = 4
LEVEL_FATAL = 5
```

以下四行代码生成get和set函数:
```
 attr_accessor :out
 attr_accessor :level
 attr_accessor :tag
 attr_accessor :time_format
```

在log的实现中，有一个实例变量： @threads_exclude_events，记录了互斥的线程列表。

以trace为例，每个不同的日志等级包含三个函数：

```
  def on_trace(&block)
    return if @level > LEVEL_TRACE
    block.call if block
  end

  def trace(*args, &block)
    return if @level > LEVEL_TRACE
    args << block.call if block
    time, msg = event(:trace, args)
    puts [@color_trace, caller_line(time, 1, LEVEL_TRACE), msg, @color_reset].join
  end
  alias TRACE trace

  def trace_backtrace(backtrace=$!.backtrace)
    return if @level > LEVEL_TRACE
    time = Time.now
    backtrace.each {|msg|
      puts ["  ", caller_line(time, 4, LEVEL_TRACE), msg].join
    }
    nil
  end

```

&block指出了block是个proc，可以使用call函数调用。

## 3.2 start

start 函数完成程序的启动和精灵化:

```
 def start
    require 'fluent/load'
    @log.init

    dry_run if @dry_run
    start_daemonize if @daemonize
    install_supervisor_signal_handlers
    until @finished
      supervise do
        read_config
        change_privilege
        init_engine
        install_main_process_signal_handlers
        run_configure
        finish_daemonize if @daemonize
        run_engine
        exit 0
      end
      $log.error "fluentd main process died unexpectedly. restarting." unless @finished
    end
  end
```

[loader.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/load.rb)包含加载了所fluentd所有的模块:

```
require 'thread'
require 'socket'
require 'fcntl'
require 'time'
...
require 'cool.io'
require 'fluent/env'
require 'fluent/version'
require 'fluent/log'
require 'fluent/status'
require 'fluent/config'
...
```

在ruby中可以使用以下代码捕获传递给进程的信号:

```
trap :INT do puts("int") end

# 给监督者设置信号捕获函数
def install_supervisor_signal_handlers

# 收到:int, :term信号时如果main进程还没有退出，则把相应的信号也转给main.
# 收到:hub信号时将对main进行重启。

end

# 给主进程设置信号捕获函数
def install_main_process_signal_handlers
# 收到:int, :term信号时fluentd主进程将停止
# 收到:hub信号时将重启，但还未实现
# 收到:user1信号时将刷新引擎
```

在supervisor中read_config函数读取配置文件，将其存放到@config_data。

如果启动时指定了参数opt[:chgroup]，change_change_privilege函数在调用时将改变进程的real和有效组id。

```
Process::GID.change_privilege(group) → fixnum click to toggle source
Change the current process’s real and effective group ID to that specified by group. Returns the new group ID. Not available on all platforms.

[Process.gid, Process.egid]          #=> [0, 0]
Process::GID.change_privilege(33)    #=> 33
[Process.gid, Process.egid]          #=> [33, 33]
```

** 有效用户ID[编辑] **
  有效用户ID（Effective UID，即EUID）与有效用户组ID（Effective Group ID，即EGID）在创建与访问文件的时候发挥作用；具体来说，创建文件时，系统内核将根据创建文件的进程的EUID与EGID设定文件的所有者/组属性，而在访问文件时，内核亦根据访问进程的EUID与EGID决定其能否访问文件。

** 真实用户ID[编辑] **
  真实用户ID（Real UID,即RUID）与真实用户组ID（Real GID，即RGID）用于辨识进程的真正所有者，且会影响到进程发送信号的权限。没有超级用户权限的进程仅在其RUID与目标进程的RUID相匹配时才能向目标进程发送信号，例如在父子进程间，子进程从父进程处继承了认证信息，使得父子进程间可以互相发送信号。

## 3.2.1 守护进程编程

又称精灵进程，可使在终端启动的进程变为在后台执行，一般服务器程序都会把自己变成守护进程。变成守护进程有以下几个歩凑，以C语言为例:

**1.在后台运行。**
为避免挂起控制终端将Daemon放入后台执行。方法是在进程中调用fork使父进程终止，让Daemon在子进程中后台执行。

    if(pid=fork())
        exit(0); //是父进程，结束父进程，子进程继续

**2.脱离控制终端，登录会话和进程组 **

进程属于一个进程组，进程组号（GID）就是进程组长的进程号（PID）。登录会话可以包含多个进程组。这些进程组共享一个控制终端。这个控制终端通常是创建进程的登录终端。控制终端，登录会话和进程组通常是从父进程继承下来的。我们的目的就是要摆脱它们，使之不受它们的影响。方法是在第1点的基础上，调用setsid()使进程成为会话组长：

    setsid();

说明：当进程是会话组长时setsid()调用失败。但第一点已经保证进程不是会话组长。setsid()调用成功后，进程成为新的会话组长和新的进程组长，并与原来的登录会话和进程组脱离。由于会话过程对控制终端的独占性，进程同时与控制终端脱离。

**3.禁止进程重新打开控制终端**

现在，进程已经成为无终端的会话组长。但它可以重新申请打开一个控制终端。可以通过使进程不再成为会话组长来禁止进程重新打开控制终端：

    if(pid=fork())
        exit(0); //结束第一子进程，第二子进程继续（第二子进程不再是会话组长）

所以一般精灵进程都会fork两次.

** 4.关闭打开的文件描述符 **

进程从创建它的父进程那里继承了打开的文件描述符。如不关闭，将会浪费系统资源，造成进程所在的文件系统无法卸下以及引起无法预料的错误。按如下方法关闭它们：

    for(i=0;i 关闭打开的文件描述符close(i);>

** 5.改变当前工作目录 **

进程活动时，其工作目录所在的文件系统不能卸下。一般需要将工作目录改变到根目录。对于需要转储核心，写运行日志的进程将工作目录改变到特定目录如 /tmpchdir("/")

** 6.重设文件创建掩模 **

进程从创建它的父进程那里继承了文件创建掩模。它可能修改守护进程所创建的文件的存取位。为防止这一点，将文件创建掩模清除：umask(0);

** 7. 处理SIGCHLD信号**

处理SIGCHLD信号并不是必须的。但对于某些进程，特别是服务器进程往往在请求到来时生成子进程处理请求。如果父进程不等待子进程结束，子进程将成为僵尸进程（zombie）从而占用系统资源。如果父进程等待子进程结束，将增加父进程的负担，影响服务器进程的并发性能。在Linux下可以简单地将 SIGCHLD信号的操作设为SIG_IGN。

    signal(SIGCHLD,SIG_IGN);

这样，内核在子进程结束时不会产生僵尸进程。这一点与BSD4不同，BSD4下必须显式等待子进程结束才能释放僵尸进程。
