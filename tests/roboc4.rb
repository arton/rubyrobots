require 'drb/drb'

class Boo
  include DRbUndumped
  def hello
    puts "hello I'm Boo"
  end
end

if ARGV.size != 1
  $stderr.puts "usage: #{$0} robos_uri"
  exit 1
end

DRb.start_service
r = DRbObject.new(nil, ARGV[0])
r = r.getself
b = Boo.new
r.are_you_there b
r.quit

