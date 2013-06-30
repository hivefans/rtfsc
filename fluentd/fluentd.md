项目地址：[fluentd](https://github.com/fluent/fluentd?source=c)

项目官网：[http://fluentd.org/](http://fluentd.org/)

项目描述：一个ruby编写的日志搜集系统。Log Everything in JSON

# 1. intro
---
fluentd是最近在使用的一个日志收集系统，它可以很方便的为其编写不同的输入输出插件，并且已经有了很多支持：[plugin](http://fluentd.org/plugin/)。因为工作中经常使用ruby，所以便对其源码产生了兴趣，我将对其进行一步步细致的分析学习，以加深对ruby的理解和更好的使用它。

READ THE * SOURCE CODE.

整个项目路径如下：

```
AUTHORS         Gemfile         bin             fluentd.gemspec
COPYING         README.rdoc     conf            lib
ChangeLog       Rakefile        fluent.conf     test
```


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
[链接](https://github.com/fluent/fluentd/blob/master/lib/fluent/command/cat.rb)

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

`ARGV` 是ruby程序使用的参数的常量数组。









