class A
  class << self
    def class_name
      to_s
    end
  end
end

A.define_singleton_method(:who_am_i) do
  "I am:#{class_name}"
end

puts A.who_am_i # ==> "I am:A"

guy = "Bob"
guy.define_singleton_method(:hello) {
  "#{self}: Helo there!"
}
puts guy.hello


class B
  def initialize()
    define_singleton_method(:tt) {
      puts("time")
    }
  end
end

s = B.new
s.tt
