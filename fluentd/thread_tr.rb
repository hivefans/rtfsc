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
