require 'robot'

class Traveler < Robot

  def initialize
    @cur_dir = 0
    super
  end

  def keep_moving
    x, y = loc

    bef = @cur_dir
    case @cur_dir
    when 0
      @cur_dir = 90 if x > 900
    when 90
      @cur_dir = 180 if y > 900
    when 180
      @cur_dir = 270 if x < 100
    when 270
      @cur_dir = 0 if y < 100
    end

    p "#{bef} to #{@cur_dir}" if bef != @cur_dir

    drive @cur_dir, 100
  end

  def run
    Thread.start do
      while alive
	keep_moving
	sleep 1
      end
    end

    scan_dir, scan_cnt, scan_res = 0, 0, 3
    while alive do
      if scan_cnt <= 0
	scan_dir = (@cur_dir - 6 + 360) % 360
	scan_cnt = 90 / scan_res
      end
      range = scanner scan_dir, scan_res
      if range > 0 && range <= 700
	cannon scan_dir, range
	scan_dir = (scan_dir - 10 + 360) % 360
      end
      scan_dir = (scan_dir + scan_res) % 360 
      scan_cnt -= 1
    end
  end

end

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "usage: #{$0} rubyot_uri"
    exit 1
  end
  Robot.main Traveler, ARGV[0]
end
