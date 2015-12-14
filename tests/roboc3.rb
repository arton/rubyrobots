require 'drb/drb'
require 'robos3'

if ARGV.size != 1
  $stderr.puts "usage: #{$0} robos_uri"
  exit 1
end

DRb.start_service
r = DRbObject.new(nil, ARGV[0])
r = r.getself
r.are_you_there
r.set_val 10, 128
p r.get_val 10
r.array[10] = 256
p r.get_val 10
r.quit

