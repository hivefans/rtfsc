# 2. 可执行文件(bin)
---
[bin](https://github.com/fluent/fluentd/tree/master/bin) 路径下存放了fluentd的可执行文件脚本：

## 2.1 fluent-cat
---
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
---
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
当你输入字符串的时候，可以看到每次`Thread.current`都不一样。

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

writer mixin了Monitor，而TimerThread是一个简单的定时器实现。

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







