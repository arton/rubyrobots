require 'robot'

class Lighthouse < Robot

  def run
    while alive
      (0..359).each do |dir|
        break unless alive
        range = scanner dir, 5
        if range > 0 && range < 700
          cannon dir, range
        end
      end
    end
  end
end

if ARGV.size != 1
  $stderr.puts "usage: #{$0} rubyot_uri"
else
  Robot.main Lighthouse, ARGV[0]
end
