# -*- coding: utf-8 -*-
 require 'monitor'

 # 和mutex一样的用法，但是嵌套没有问题.
 lock = Monitor.new
 lock.synchronize do
   lock.synchronize do
     puts "nce"
   end
 end


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
