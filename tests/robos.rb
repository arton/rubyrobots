require 'drb/drb'
$mswin = RUBY_PLATFORM.index "mswin"
class Robot
  def cannon(deg, rng)
    puts "cannon: deg=#{deg}, rng=#{rng}"
  end
  def scanner(deg, rng)
    puts "scanner: deg=#{deg}, rng=#{rng}"
  end
  def quit
    unless $mswin.nil?
      Thread.start do
	sleep 1
	DRb.stop_service
      end
    end
  end
end

DRb.start_service('druby://:6850', Robot.new)
puts DRb.uri
if $mswin.nil?
  puts "to exit, hit return"
  gets
else
  DRb.thread.join
end

