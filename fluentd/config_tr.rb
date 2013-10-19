# -*- coding: utf-8 -*-
class ConfigError < StandardError
end

class ConfigParseError < ConfigError
end


module Config
  class Element < Hash
    def initialize(name, arg, attrs, elements, used=[])
      @name = name
      @arg = arg
      @elements = elements
      super()
      attrs.each {|k,v|
        self[k] = v
      }
      @used = used
    end

    attr_accessor :name, :arg, :elements, :used

    def add_element(name, arg='')
      e = Element.new(name, arg, {}, [])
      @elements << e
      e
    end

    def +(o)
      Element.new(@name.dup, @arg.dup, o.merge(self), @elements+o.elements, @used+o.used)
    end

    def has_key?(key)
      @used << key
      super
    end

    def [](key)
      @used << key
      super
    end

    def check_not_fetched(&block)
      each_key {|key|
        unless @used.include?(key)
          block.call(key, self)
        end
      }
      @elements.each {|e|
        e.check_not_fetched(&block)
      }
    end

    def to_s(nest = 0)
      indent = "  "*nest
      nindent = "  "*(nest+1)
      out = ""
      if @arg.empty?
        out << "#{indent}<#{@name}>\n"
      else
        out << "#{indent}<#{@name} #{@arg}>\n"
      end
      each_pair {|k,v|
        out << "#{nindent}#{k} #{v}\n"
      }
      @elements.each {|e|
        out << e.to_s(nest+1)
      }
      out << "#{indent}</#{@name}>\n"
      out
    end
  end

  def self.read(path)
    Parser.read(path)
  end

  def self.parse(str, fname, basepath=Dir.pwd)
    Parser.parse(str, fname, basepath)
  end

  def self.new(name='')
    Element.new('', '', {}, [])
  end

  def self.size_value(str)
    case str.to_s
    when /([0-9]+)k/i
      $~[1].to_i * 1024
    when /([0-9]+)m/i
      $~[1].to_i * (1024**2)
    when /([0-9]+)g/i
      $~[1].to_i * (1024**3)
    when /([0-9]+)t/i
      $~[1].to_i * (1024**4)
    else
      str.to_i
    end
  end

  def self.time_value(str)
    case str.to_s
    when /([0-9]+)s/
      $~[1].to_i
    when /([0-9]+)m/
      $~[1].to_i * 60
    when /([0-9]+)h/
      $~[1].to_i * 60*60
    when /([0-9]+)d/
      $~[1].to_i * 24*60*60
    else
      str.to_f
    end
  end

  def self.bool_value(str)
    case str.to_s
    when 'true', 'yes'
      true
    when 'false', 'no'
      false
    else
      nil
    end
  end

  private
  class Parser
    def self.read(path)
      path = File.expand_path(path)
      puts("path #{path}")
      File.open(path) {|io|
        parse(io, File.basename(path), File.dirname(path))
      }
    end

    def self.parse(io, fname, basepath=Dir.pwd)
      attrs, elems = Parser.new(basepath, io.each_line, fname).parse!(true)
      puts("attr #{attrs} elems #{elems}")
      Element.new('ROOT', '', attrs, elems)
    end

    def initialize(basepath, iterator, fname, i=0)
      @basepath = basepath
      @iterator = iterator
      @i = i
      @fname = fname
    end

    def parse!(allow_include, elem_name=nil, attrs={}, elems=[])
      while line = @iterator.next
        @i += 1
        line.lstrip!
        # 去掉注释
        line.gsub!(/\s*(?:\#.*)?$/,'')
        if line.empty?
          next
        elsif m = /^\<([a-zA-Z0-9_]+)\s*(.+?)?\>$/.match(line)
          e_name = m[1]
          e_arg = m[2] || ""
          # 元素的开始，进行递归操作.
          e_attrs, e_elems = parse!(false, e_name)
          elems << Element.new(e_name, e_arg, e_attrs, e_elems)
        elsif line == "</#{elem_name}>"
          # 元素的结尾，递归结束.
          break
        elsif m = /^([a-zA-Z0-9_]+)\s*(.*)$/.match(line)
          key = m[1]
          value = m[2]
          # 解析内部element,按key value分割.
          if allow_include && key == 'include'
            process_include(attrs, elems, value)
          else
            attrs[key] = value
          end
          next
        else
          # 如果遇到错误，抛出异常.
          raise ConfigParseError, "parse error at #{@fname} line #{@i}"
        end
      end

      return attrs, elems
    rescue StopIteration
      return attrs, elems
    end

    # 解析包含头文件.
    def process_include(attrs, elems, uri)
      u = URI.parse(uri)
      if u.scheme == 'file' || u.path == uri  # file path
        path = u.path
        if path[0] != ?/
          pattern = File.expand_path("#{@basepath}/#{path}")
        else
          pattern = path
        end

        Dir.glob(pattern).each {|path|
          basepath = File.dirname(path)
          fname = File.basename(path)
          File.open(path) {|f|
            Parser.new(basepath, f.each_line, fname).parse!(true, nil, attrs, elems)
          }
        }

      else
        basepath = '/'
        fname = path
        require 'open-uri'
        open(uri) {|f|
          Parser.new(basepath, f.each_line, fname).parse!(true, nil, attrs, elems)
        }
      end

    rescue SystemCallError
      raise ConfigParseError, "include error at #{@fname} line #{@i}: #{$!.to_s}"
    end
  end
end


