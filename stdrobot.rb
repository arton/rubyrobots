require 'drb/drb'

if ARGV.size != 1
  puts 'usage: stdrobot.rb RobotOffice_uri'
  exit 1
end

class ILoveCUI
  include DRbUndumped

  def initialize(uri)
    DRb.start_service
    @alive = true
    @numrobs = 0
    @office = DRbObject.new(nil, uri)
    @office.add_canvas self
  end

  def update(*arg)
    arg.each do |a|
      p a
      if a[0] == 'win' || a[0] == 'close'
        @alive = false
      elsif a[0] == 'newrobot'
        @numrobs += 1
      end
    end
  end

  def run
    while @numrobs < 2
      sleep 1
    end
    @office.start self
    while @alive
      sleep 1
    end
    @office.shutdown self
    DRb.stop_service
  end
end

i = ILoveCUI.new ARGV[0]
i.run
