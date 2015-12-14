require 'drb/drb'

class Robot
  def run(uri)
    DRb.start_service
    r = DRbObject.new(nil, uri)
    (0..3).each do |i|
      r.cannon i, 8 * i
      r.scanner i, 4 * i
    end
    r.quit
  end
end

if ARGV.size != 1
  $stderr.puts "usage: #{$0} robos_uri"
  exit 1
end
r = Robot.new
r.run ARGV[0]

