require 'drb/drb'

class Robot
  include DRbUndumped
  def getself
    self
  end
  def are_you_there(c)
    c.hello
    puts "hello world!"
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

