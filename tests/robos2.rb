require 'drb/drb'

class Robot
#  include DRbUndumped
  def getself
    self
  end
  def cannon(deg, rng)
    puts "cannon: deg=#{deg}, rng=#{rng}"
  end
  def quit
    Thread.start do
      sleep 1
      DRb.stop_service
    end
  end
end

DRb.start_service('druby://:6850', Robot.new)
puts DRb.uri
DRb.thread.join

