if $0 == __FILE__
  puts "program your own robot !"
  exit 1
end

require 'drb/drb'

class Robot
  include DRbUndumped

  attr_reader :name, :alive

  def initialize
    @name = "#{self.class}:[#{$$}]"
    @robot, @killed, @alive = nil, false, false
  end

  def main(url)
    bfld = DRbObject.new(nil, url)
    @robot = bfld.join(self, @name)
    if @robot.nil?
      $stderr.puts "can't join the battle field"
    else
      until @alive do
	sleep 1
      end
      unless @killed
	run
      end
    end
  end

  def self.main(k, url)
    unless Robot == k.superclass
      $stderr.puts "bad class"
      exit 1
    end
    DRb.start_service
    r = k.new
    r.main url
    sleep 3
    DRb.stop_service
  end

  def kill(s)
    puts s
    @killed = true
    @alive = !@alive
  end

  def start
    @alive = true
  end

protected

  def scanner(dir, reg)
    @robot.scanner dir, reg
  end

  def cannon(dir, reg)
    @robot.cannon dir, reg
  end

  def drive(dir, speed)
    @robot.drive dir, speed
  end

  def dsp
    @robot.dsp
  end

  def damage
    @robot.damage
  end

  def speed
    @robot.speed
  end

  def tick
    @robot.tick
  end

  def heat
    @robot.heat
  end

  def loc
    @robot.loc
  end

end
