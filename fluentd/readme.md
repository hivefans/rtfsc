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

** 1.在后台运行 **

为避免挂起控制终端将Daemon放入后台执行。方法是在进程中调用fork使父进程终止，让Daemon在子进程中后台执行。

    if(pid=fork())
        exit(0); //是父进程，结束父进程，子进程继续

** 2.脱离控制终端，登录会话和进程组 **

进程属于一个进程组，进程组号（GID）就是进程组长的进程号（PID）。登录会话可以包含多个进程组。这些进程组共享一个控制终端。这个控制终端通常是创建进程的登录终端。控制终端，登录会话和进程组通常是从父进程继承下来的。我们的目的就是要摆脱它们，使之不受它们的影响。方法是在第1点的基础上，调用setsid()使进程成为会话组长：

    setsid();

说明：当进程是会话组长时setsid()调用失败。但第一点已经保证进程不是会话组长。setsid()调用成功后，进程成为新的会话组长和新的进程组长，并与原来的登录会话和进程组脱离。由于会话过程对控制终端的独占性，进程同时与控制终端脱离。

** 3.禁止进程重新打开控制终端 **

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

** 7. 处理SIGCHLD信号 **

处理SIGCHLD信号并不是必须的。但对于某些进程，特别是服务器进程往往在请求到来时生成子进程处理请求。如果父进程不等待子进程结束，子进程将成为僵尸进程（zombie）从而占用系统资源。如果父进程等待子进程结束，将增加父进程的负担，影响服务器进程的并发性能。在Linux下可以简单地将 SIGCHLD信号的操作设为SIG_IGN。

    signal(SIGCHLD,SIG_IGN);

这样，内核在子进程结束时不会产生僵尸进程。这一点与BSD4不同，BSD4下必须显式等待子进程结束才能释放僵尸进程。

## 3.2.2 fluentd守护进程编程

再看看fluentd-ruby是如何实现守护进程的：

对于ruby来说，fork会返回两次，对于父进程返回fork的进程id，对于子进程返回nil，所以这段代码完成第一步:

```
 # 创建一个管道，用来和父进程通信。
 @wait_daemonize_pipe_r, @wait_daemonize_pipe_w = IO.pipe
 if fork
      # console process, 父进程只需要读，因此将写端关闭。
      @wait_daemonize_pipe_w.close
      @wait_daemonize_pipe_w = nil
      wait_daemonize
      exit 0
    end
```

父进程不会像之前的C语言描述流程那样立刻退出，而是等待精灵化完成，并将监督者的pid写入文件再退出.
```
 def wait_daemonize
    supervisor_pid = @wait_daemonize_pipe_r.read
    if supervisor_pid.empty?
      # initialization failed
      exit! 1
    end

    @wait_daemonize_pipe_r.close
    @wait_daemonize_pipe_r = nil

    # write pid file
    File.open(@daemonize, "w") {|f|
      f.write supervisor_pid
    }
  end

```

对于子进程，将读端关闭，因为不需要读:
```
    # daemonize intermediate process
    @wait_daemonize_pipe_r.close
    @wait_daemonize_pipe_r = nil
```

下面这句代码比较有意思：
```
    # in case the child process forked during run_configure
    @wait_daemonize_pipe_w.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
```
Fcntl::FD_CLOEXEC有什么作用呢，我们知道当进程fork一个子进程时，是会继承其打开的文件描述符的，而这个Fcntl::FD_CLOEXEC标志支持通过execl执行的程序里，此描述符被关闭，不能再使用它;

```
\#include <fcntl.h>
\#include <unistd.h>
\#include <stdio.h>
\#include <string.h>

int main(void)
{
        int fd,pid;
        char buffer[20];
        fd=open("wo.txt",O_RDONLY);
        printf("%d/n",fd);
        int val=fcntl(fd,F_GETFD);
        val|=FD_CLOEXEC;
        fcntl(fd,F_SETFD,val);

        pid=fork();
        if(pid==0)
        {
                //子进程中，此描述符并不关闭，仍可使用
                char child_buf[2];
                memset(child_buf,0,sizeof(child_buf) );
                ssize_t bytes = read(fd,child_buf,sizeof(child_buf)-1 );
                printf("child, bytes:%d,%s/n/n",bytes,child_buf);

                //execl执行的程序里，此描述符被关闭，不能再使用它
                char fd_str[5];
                memset(fd_str,0,sizeof(fd_str));
                sprintf(fd_str,"%d",fd);
                int ret = execl("./exe1","exe1",fd_str,NULL);
                if(-1 == ret)
                        perror("ececl fail:");
        }
        waitpid(pid,NULL,0);
        memset(buffer,0,sizeof(buffer) );
        ssize_t bytes = read(fd,buffer,sizeof(buffer)-1 );
        printf("parent, bytes:%d,%s/n/n",bytes,buffer);
}

```

```
cat exe1.c
#include <fcntl.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
int main(int argc, char **args)
{
        char buffer[20];
        int fd = atoi(args[1]);
        memset(buffer,0,sizeof(buffer) );
        ssize_t bytes = read(fd,buffer,sizeof(buffer)-1);
        if(bytes < 0)
        {
                perror("exe1: read fail:");
                return -1;
        }
        else
        {
                printf("exe1: read %d,%s/n/n",bytes,buffer);
        }
        return 0;
}
```

以下是守护进程的剩余代码:

```
# 将进程设置为进程组组长:
Process.setsid
# 第二次fork.
exit!(0) if fork
# 清楚文件创建掩码
File.umask(0)
```


以下代码将标准输入输出和错误定向到/dev/null，将监督者进程的pid写入到文件，然后结束。
```
 def finish_daemonize
    if @wait_daemonize_pipe_w
      STDIN.reopen("/dev/null")
      STDOUT.reopen("/dev/null", "w")
      STDERR.reopen("/dev/null", "w")
      @wait_daemonize_pipe_w.write @supervisor_pid.to_s
      @wait_daemonize_pipe_w.close
      @wait_daemonize_pipe_w = nil
    end
  end
```

## 3.3 引擎初始化

下面代码进行引擎初始化，主要是加载插件:
```
def init_engine
    require 'fluent/load'
    Fluent::Engine.init
    if @suppress_interval
      Fluent::Engine.suppress_interval(@suppress_interval)
    end

    @libs.each {|lib|
      require lib
    }

    @plugin_dirs.each {|dir|
      if Dir.exist?(dir)
        dir = File.expand_path(dir)
        Fluent::Engine.load_plugin_dir(dir)
      end
    }
  end
```

最后执行:
```
def run_engine
    Fluent::Engine.run
end
```

# 4 插件

[plugin.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/plugin.rb )fluent支持三种不同类型的插件:输入，输出，缓冲。
现在它已经具有有大量已实现[插件](http://fluentd.org/plugin/)，可以浏览一下有没有你想做的。

`File.expand_path`将一个路径转为绝对路径：

```
File.expand_path("~oracle/bin")           #=> "/home/oracle/bin"
File.expand_path("../../bin", "/tmp/x")   #=> "/bin"
```

`Dir.entries`返回一个路径下的所有文件.

先将插件文件夹下的ruby文件加载到内存:
```
  def load_plugins
    dir = File.join(File.dirname(__FILE__), "plugin")
    load_plugin_dir(dir)
    load_gem_plugins
  end

  def load_plugin_dir(dir)
    dir = File.expand_path(dir)
    Dir.entries(dir).sort.each {|fname|
      if fname =~ /\.rb$/
        require File.join(dir, fname)
      end
    }
    nil
  end
```

PluginClass将实例化一个对象，维护各种插件的类型和名字与代码类的对应关系，提供new等方法。
下面是各个插件的基类:

[input.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/input.rb)

# 5

有一个函数基本用法如下：[define_singleton_method](http://apidock.com/ruby/Object/define_singleton_method):

```
class A
  class << self
    def class_name
      to_s
    end
  end
end
A.define_singleton_method(:who_am_i) do
  "I am: #{class_name}"
end
A.who_am_i   # ==> "I am: A"

guy = "Bob"
guy.define_singleton_method(:hello) { "#{self}: Hello there!" }
guy.hello    #=>  "Bob: Hello there!"

```
[mixin.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/mixin.rb)也使用这个函数：

```
 define_singleton_method(:format_nocache) {|time|
          Time.at(time).strftime(format)
        }
```

使用define_singleton_method不产生新的作用域，可以直接访问format参数.


# 6. config.rb

[config.rb](https://github.com/fluent/fluentd/blob/master/lib/fluent/config.rb) 这个模块的作用是解析fluentd的配置文件，配置文件的格式如下:

```
<source>
  type mytail
  path /Users/zhuoyikang/Project/galaxy-empire-server-2/log/track.txt
  tag mongo.ge2
  # format /^*(?<message>.*)$/
</source>


<match mongo.**>
  type stdout
  # type mongo
  # database fluent
  # collection access

  # host localhost
  # port 27017

  flush_interval 10s 
</match>

## built-in TCP input
## $ echo <json> | fluent-cat <tag>
<source>
  type forward
</source>

## built-in UNIX socket input
#<source>
#  type unix
#</source>

# HTTP input
# http://localhost:8888/<tag>?json=<json>
<source>
  type http
  port 8888
</source>

## File input
## read apache logs with tag=apache.access
#<source>
#  type tail
#  format apache
#  path /var/log/httpd-access.log
#  tag apache.access
#</source>

# Listen DRb for debug
<source>
  type debug_agent
  port 24230
</source>


## match tag=apache.access and write to file
#<match apache.access>
#  type file
#  path /var/log/fluent/access
#</match>

## match tag=debug.** and dump to console
<match debug.**>
  type stdout
</match>

## match tag=system.** and forward to another fluent server
#<match system.**>
#  type forward
#  host 192.168.0.11
#  <secondary>
#    host 192.168.0.12
#  </secondary>
#</match>

## match tag=myapp.** and forward and write to file
#<match myapp.**>
#  type copy
#  <store>
#    type forward
#    host 192.168.0.13
#    buffer_type file
#    buffer_path /var/log/fluent/myapp-forward
#    retry_limit 50
#    flush_interval 10s
#  </store>
#  <store>
#    type file
#    path /var/log/fluent/myapp
#  </store>
#</match>

## match fluent's internal events
#<match fluent.**>
#  type null
#</match>

## match not matched logs and write to file
#<match **>
#  type file
#  path /var/log/fluent/else
#  compress gz
#</match>


```

这种配置文件简单易懂，是一个树形结构，运用了常见的组合模式，并且支持文件包含，这个东东可以在其他项目中直接拷贝过去使用.



`module Configurable`用来给其他模块包含，使用一种比较普遍的ruby编程模式:

```
module SomeModule
    def self.included(mod)
       mod.extend(ClassMethods)
    end

    module ClassMethods
       def some_method
       end
    end
end

# 这样include SomeModule的类将包含ClassMethods模块中的方法为类方法。
```

config_param 是一个类宏，用来定义参数，比如buffer.rb里面的:

```
config_param :buffer_chunk_limit, :size, :default => 8*1024*1024
config_param :buffer_queue_limit, :integer, :default => 256

```

定义格式为:`config_param 参数名字, 参数类型, 参数Option`

参数类型有:

```
      block ||= case type
          when :string, nil
            Proc.new {|val| val }
          when :integer
            Proc.new {|val| val.to_i }
          when :float
            Proc.new {|val| val.to_f }
          when :size
            Proc.new {|val| Config.size_value(val) }
          when :bool
            Proc.new {|val| Config.bool_value(val) }
          when :time
            Proc.new {|val| Config.time_value(val) }
          else
            raise ArgumentError, "unknown config_param type `#{type}'"
          end

```

```
    module ClassMethods
    def config_param(name, *args, &block)
      name = name.to_sym

```

