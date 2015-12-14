require 'drb/drb'

class Robot
  if ARGV[0] == 'U'
    include DRbUndumped
  end
  def initialize
    @array = Array.new(100)
  end
  attr_accessor :array
  def getself
    self
  end
  def are_you_there
    puts "hello world!"
  end
  def set_val(i, v)
    @array[i] = v
  end
  def get_val(i)
    @array[i]
  end
  def quit
    Thread.start do
      sleep 1
      DRb.stop_service
    end
  end
end

if $0 == __FILE__
  DRb.start_service('druby://:6850', Robot.new)
  puts DRb.uri
  DRb.thread.join
end

