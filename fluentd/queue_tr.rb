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
