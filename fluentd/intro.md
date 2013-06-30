项目地址：[fluentd](https://github.com/fluent/fluentd?source=c)

项目官网：[http://fluentd.org/](http://fluentd.org/)

项目描述：一个ruby编写的日志搜集系统。Log Everything in JSON

---
fluentd是最近在使用的一个日志收集系统，它可以很方便的为其编写不同的输入输出插件，并且已经有了很多支持：[plugin](http://fluentd.org/plugin/)。因为工作中经常使用ruby，所以便对其源码产生了兴趣，我将对其进行一步步细致的分析学习，以加深对ruby的理解和更好的使用它。

READ THE * SOURCE CODE.

整个项目路径如下：

```
AUTHORS         Gemfile         bin             fluentd.gemspec
COPYING         README.rdoc     conf            lib
ChangeLog       Rakefile        fluent.conf     test
```
