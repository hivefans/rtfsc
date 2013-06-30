require "thread"

m = Mutex.new
v = 0
thread_list = []

(1..100).each do
  thread_list << Thread.new {
    m.synchronize {
      v = v + 100
    }
  }
end

thread_list.each do |t|
  t.join
end

puts(v)

