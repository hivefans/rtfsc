ids = [1,2,3]

def targs(*ids)
  puts ids
  puts "----"
  puts ids
end

targs *ids
#=> 1
#=> 3
#targs *ids
#=> 3
#=> 3
