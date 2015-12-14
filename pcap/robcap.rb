require 'pcaplet'
robocap = Pcaplet.new('-s 1500')

ROBO_REQ = Pcap::Filter.new('tcp and port 6852', robocap.capture)
robocap.add_filter ROBO_REQ
robocap.each_packet do |pkt|
  flag = ''
  flag << 'S' if pkt.tcp_syn?
  flag << 'A' if pkt.tcp_ack?
  flag << 'P' if pkt.tcp_psh?
  flag << 'R' if pkt.tcp_rst?
  flag << 'F' if pkt.tcp_fin?
  a = pkt.time.to_a
  u = pkt.time.usec
  tm = sprintf "%02d:%02d:%02d:%03d.%03d ", a[2], a[1], a[0], u / 1000, u % 1000
	       
  puts "#{tm}#{pkt.src.to_num_s}:#{pkt.sport} => #{pkt.dst.to_num_s}:#{pkt.dport} (#{flag})"
  unless pkt.tcp_data.nil?
    ud = pkt.tcp_data.unpack('H*')[0]
    s = pkt.tcp_data.dup
    s.gsub! /[^ -z]/m, '.'
    puts ' 0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F   ASCII'
    i = 0
    while i < pkt.tcp_data_len
      j = (pkt.tcp_data_len - i >= 16) ? 16 : pkt.tcp_data_len - i
      ds = ''
      (0...j).each do |x|
	ds << ud[i*2 + x*2,2] << ' '
      end
      if j < 16
	(j...16).each do |x|
	  ds << '   '
	end
      end
      ds << '  ' << s[i,j]
      puts ds
      i += j
    end
    puts ''
  end
end
