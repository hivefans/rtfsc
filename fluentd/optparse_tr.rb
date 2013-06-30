# -*- coding: utf-8 -*-
# 编码使用以下optparse
require 'optparse'

op = OptionParser.new
port = 23
host =  "127.0.0.1"

op.on('-p', '--port PORT', "test tcp port (default #{port})", Integer) { |i|
  port = i
}

op.parse!(ARGV)

# puts "argv #{ARGV}"
# if ARGV.length != 1
#   puts op.to_s
# end
# op.parse!(ARGV)
# puts op.to_s
