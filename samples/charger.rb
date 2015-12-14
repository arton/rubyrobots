require 'robot'

class Charger < Robot

  def run
    dir = rand 360
    nothing = 0
    closest = 0
    while alive do
      rng = scanner dir, 10

      p "rng=#{rng}, dir=#{dir}"

      if rng > 0 && rng < 700
	start = (dir + 20) % 360
	limit = 1
	while alive && limit <= 40
	  dir = (start - limit + 360) % 360
	  rng = scanner dir, 1
	  if rng > 0 && rng <= 700
	    nothing = 0
	    cannon dir, rng
	    drive dir, 70
	    limit -= 4
	    next
	  end
	  limit += 1
	end
      else
	nothing += 1
	if rng > 700
	  closest = dir
	end
      end

      return unless alive

      drive 0, 0
      if nothing >= 30
	nothing = 0
	drive closest, 100
	sleep 10
	drive 0, 0
      end

      dir = (dir - 20 + 360) % 360
    end
  end

end

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "usage: #{$0} rubyot_uri"
    exit 1
  end
  Robot.main Charger, ARGV[0]
end
