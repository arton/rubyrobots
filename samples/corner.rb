require 'robot'
include Math

class Corner < Robot

  CORNERS = [[10, 10], [990, 10], [10, 990], [990, 990]]
  COR_DIR = [0, 90, 270, 180]
  RAD2DEG = 57.2958

  def run
    x, y = loc
    if (x < 500) 
      x, s1 = 10, false
    else
      x, s1 = 990, true
    end
    if y < 500
      y, s2 = 10, false
    else
      y, s2 = 990, true
    end
    if s1 && s2
      start, new_corner = 180, 3
    elsif s1 && !s2
      start, new_corner = 90, 1
    elsif !s2 && s2
      start, new_corner = 270, 2
    else
      start, new_corner = 0, 0
    end
    dir = start
    goto x, y
    dam, num_scans, resincr = 0, 5, 5

    while alive do
      while alive && num_scans > 0 && (dam + 10) > damage
	rng = scanner dir, resincr
	if rng > 0 && rng <= 700
	  resincr = 1
	  cannon dir, rng
	  dir -= 8
	end
	dir += resincr
	if dir >= start + 90
	  num_scans -= 1
	  dir = start
	  resincr = 5
	end
      end

      return unless alive

      test_corner = rand 4
      while new_corner == test_corner
	test_corner = rand 4
      end
      new_corner = test_corner
      goto *CORNERS[new_corner]
      start = COR_DIR[new_corner]
      dam = damage
    end
  end

private
  def farfromtarget(x, y)
    cx, cy = loc
    (x - cx).abs > 40 || (y - cy).abs > 40
  end

  def gethdg(x, y)
    cx, cy = loc
    hdg = (RAD2DEG * atan2(y - cy, x - cx)).round
    hdg += 360 if hdg < 0
    hdg
  end

  def goto(x, y)
    Thread.start do
      hdg = gethdg x, y
      drive hdg, 100
      while farfromtarget(x, y) do
	hdg = gethdg x, y
	if speed <= 35
	  drive hdg, 100
	end
      end
      drive hdg, 0
    end
  end

end

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "usage: #{$0} rubyot_uri"
    exit 1
  end
  Robot.main Corner, ARGV[0]
end
