=begin
 Copyright(c) 2001 arton
== ACKNOWLEDGMENTS
  I've used many ideas, architecture, and codes from 
    Mr. Tom Poindexter (tpoindex@nyx.net)'s TclRobots.
  This is almost TclRobots Ruby port except for using ORPC.
=end

require 'thread'
require 'drb/drb'
require 'observer'
include Math

srand((($$ * 65277 + 13849) % 65536 + 65536) % 65536)

def hypot(x, y)
  sqrt(x ** 2 + y ** 2)
end

class Robot
  include DRbUndumped

  attr_accessor :status
  attr_reader :name
  attr_reader :idnum
  attr_reader :num
  attr_accessor :cmd

  attr_accessor :x
  attr_accessor :y
  attr_accessor :orgx
  attr_accessor :orgy
  attr_accessor :range
  attr_accessor :cdamage
  attr_accessor :cspeed
  attr_accessor :dspeed
  attr_accessor :hdg
  attr_accessor :dhdg
  attr_accessor :dir
  attr_accessor :sig
  attr_accessor :mstate 
  attr_accessor :reload
  attr_accessor :mused
  attr_accessor :mx
  attr_accessor :my
  attr_accessor :morgx
  attr_accessor :morgy
  attr_accessor :mhdg
  attr_accessor :mrange
  attr_accessor :mdist
  attr_accessor :cheat
  attr_accessor :hflag
  attr_accessor :btemp

  def initialize(fld, ctrl, name, idx, quad)
    @status = true
    @fld, @controller = fld, ctrl
    @name, @idnum = name, idx
    @num = ("#{name}#{idx}".hash % 65536).abs
    @x, @y = quad
    @orgx, @orgy = @x, @y
    @cdamage, @cspeed, @dspeed = 0, 0, 0
    @hdg = rand(360)
    @dhdg = @hdg
    @dir = '+'
    @sig = [0, 0]
    @mstate, @mx, @my, @reload, @mused, @mdist = false, 0, 0, 0, 0, 0
    @morgx, @morgy, @mhdg, @mrange = 0, 0, 0, 0
    @cheat, @hflag  = 0, false
    @btemp = 0
    p self if $DEBUG
  end

  def scanner(deg, res)
    do_wait
    do_wait
    res = @fld.do_scanner(@idnum, deg, res)
    res
  end

  def dsp
    do_wait
    return @sig[0], @sig[1]
  end

  def cannon(deg, range)
    do_wait
    res = @fld.do_cannon(@idnum, deg, range)
    res
  end

  def drive(deg, speed)
    do_wait
    res = @fld.do_drive(@idnum, deg, speed)
    res
  end

  def damage
    do_wait
    @cdamage
  end

  def speed
    do_wait
    @cspeed
  end

  def loc
    return @x, @y
  end

  def tick
    @fld.do_tick(@idnum)
  end

  def heat
    return @hflag, @cheat
  end

  def kill(s)
    @controller.kill s
  end

  def start
    @controller.start
  end

  def stop
    @controller.stop
  end

private
  def do_wait
    sleep 0.1
  end

end

class BattleField
  include Observable
  include DRbUndumped

  MAX_ROBOTS = 4

  TICK = 500
  STIMTICK = 500
  ERRDIST = 10
  SP = 10
  ACCEL = 10
  MISMAX = 700
  MSP = 100
  MRELOAD = ((MISMAX / MSP) + 0.5).round
  LRELOAD = MRELOAD * 3
  CLIP = 4
  TURN = [100, 50, 30, 20]
  RATE = [90, 60, 40, 30, 20]
  DIA = [6, 10, 20, 50]
  HIT = [25, 12, 7, 3]
  COLL = 5
  HEATSP = 35
  HEATMAX = 200
  HRATE = 10
  COOLING = -25
  CANHEAT = 20
  CANCOOL = -1
  SCANBAD = 35
  QUADS = [[100, 100], [600, 100], [100, 600], [600, 600]]
  D2R = 180/PI
  S_TAB, C_TAB = Array.new(360), Array.new(360)
  (0...360).each do |i|
    S_TAB[i] = sin(i/D2R)
    C_TAB[i] = cos(i/D2R)
  end

  attr_reader :running

  def initialize()
    @canvas = Hash.new
    @cookie = 1
    @robs = Array.new(MAX_ROBOTS)
    @ticks = 0
    @mutex = Mutex.new
    @quads = QUADS.dup
    @stop, @running = false, false
    @q = Queue.new
    @th = nil
  end

  def add_observer(observer)
    @observer_peers = [] unless defined? @observer_peers
    @observer_peers.push observer

    Thread.start do
      sleep 0.1
      (0...MAX_ROBOTS).each do |i|
	next if @robs[i].nil?
	observer.update "newrobot", @robs[i].idnum, @robs[i].num
      end
    end
    count_observers
  end

  def notify_observers(*arg)
    if @th.nil?
      @th = Thread.new do
	while true do
	  ag = @q.pop
	  changed
	  super *ag
	end
      end
    end
    @q.push [*arg]
  end

  def notify_otherobservers(ob, *arg)
    changed
    if defined? @observer_state and @observer_state
      if defined? @observer_peers
	@mutex.synchronize do
	  @observer_peers.each do |i|
	    next if ob == i
	    i.update(*arg)
	  end
	end
      end
    end
  end

  def add_robot(ctrl, name)
    robo = nil
    @mutex.synchronize do
      (0...MAX_ROBOTS).each do |idx|
	if @robs[idx].nil?
	  if @quads.size == 1
	    n = 0
	  else
	    n = rand(@quads.size)
	  end
	  robo = Robot.new(self, ctrl, name, idx, @quads[n])
	  @quads.delete_at n
	  @robs[idx] = robo
	  break
	end
      end
    end
    unless robo.nil?
      show_newrobot robo
    end
    robo
  end

  def do_scanner(robot, deg, res)
    return 0 if @stop || @running == false
    rob = @robs[robot]
    return 0 if rob.nil?
    return -1 if deg < 0 || deg > 359
    return -1 if res < 0 || res > 10
    show_scan rob, deg, res
    dsp, dmg, near = 0, 0, 9999
    @robs.each do |robx|
      next if (robx.nil? || robx == rob || !robx.status)
      x = robx.x - rob.x
      y = robx.y - rob.y
      d = (57.2958 * atan2(y, x)).round
      d += 360 if d < 0
      d1 = (d - deg + 360) % 360
      d2 = (deg - d + 360) % 360
      f = (d1 < d2) ? d1 : d2
      if f <= res
        dist = hypot(x, y).round
        if dist < near
          derr = ERRDIST * res
          terr = ((res > 0) ? 5 : 0) + rand(derr)
          fud1 = (rand(2) == 1) ? '-' : '+'
          fud2 = (rand(2) == 1) ? '-' : '+'
          near = eval "#{dist} #{fud1} #{terr} #{fud2} #{rob.btemp}"
          near = 1 if near < 1
          dsp = robx.num
          dmg = robx.cdamage
        end
      end
    end
    if rob.btemp >= SCANBAD
      rob.sig.fill 0
      v = 0
    else
      rob.sig[0..1] = dsp, dmg
      v = (near == 9999) ? 0 : near
    end
    v
  end

  def do_cannon(robot, deg, rng)
    return 0 if @stop || @running == false
    rob = @robs[robot]
    return 0 if rob.nil? || rob.mstate || rob.reload != 0
    return -1 if deg < 0 || deg > 359 || rng < 0 || rng > MISMAX
    
    rob.mhdg = deg
    rob.mdist = rng
    rob.mrange = 0
    rob.mstate = true
    rob.mx, rob.morgx = rob.x, rob.x
    rob.my, rob.morgy = rob.y, rob.y
    rob.btemp += CANHEAT
    rob.mused += 1
    if rob.mused == CLIP
      rob.reload = LRELOAD
      rob.mused = 0
    else
      rob.reload = MRELOAD
    end
    1
  end

  def do_drive(robot, deg, spd)
    return 0 if @stop || @running == false
    rob = @robs[robot]
    return 0 if rob.nil?
    return -1 if deg < 0 || deg > 359 || spd < 0 || spd > 100

    d1 = (rob.hdg - deg + 360) % 360
    d2 = (deg - rob.hdg + 360) % 360
    d = (d1 < d2) ? d1 : d2

    rob.dhdg = deg
    rob.dspeed = (rob.hflag && spd > HEATSP) ? HEATSP : spd
    idx = (d / 25).to_i
    idx = 3 if idx > 3
    if rob.cspeed > TURN[idx]
      rob.dspeed = 0
      rob.dhdg = rob.hdg
    else
      rob.orgx, rob.orgy, rob.range = rob.x, rob.y, 0
    end
    if (rob.hdg + d + 360) % 360 == deg
      rob.dir = '+'
    else
      rob.dir = '-'
    end
    rob.dspeed
  end

  def do_tick(robot)
    @ticks
  end

  def do_start(cv)
    return false if @robs.nitems <= 1
    notify_otherobservers cv, "start"
    @running = true
    Thread.start do
      @robs.each do |r|
	next if r.nil?
	r.start
      end
      while @running && @stop == false
	update_robots
	sleep TICK / 1000.0
      end
    end
    true
  end

  def do_stop(cv)
    @running = false
    notify_otherobservers cv, "stop"
    true
  end

  def do_shutdown(cv)
    notify_otherobservers cv, "close"
    Thread.start do
      @robs.each do |r|
	next if r.nil?
	r.kill "user shutdown"
      end
    end
    true
  end

  def do_initNew(cv)
    return if @stop == false
    notify_otherobservers cv, "initNew"
    (0...MAX_ROBOTS).each do |i|
      next if @robs[i].nil?
      r = @robs[i]
      @robs[i] = nil
      r.kill "user break at tick:#{@ticks}"
    end
    @running, @stop = false, false
    @ticks, @quads = 0, QUADS.dup
  end
  
  def update_robots
    @ticks += 1
    num_miss = 0
    num_rob = 0

    @robs.each do |r|
      next if r.nil?
      if r.mstate
	num_miss += 1
	r.mrange = r.mrange + MSP
	r.mx = (C_TAB[r.mhdg] * r.mrange).round + r.morgx
	r.my = (S_TAB[r.mhdg] * r.mrange).round + r.morgy
	if r.mrange > r.mdist
	  r.mstate = false
	  r.mx = (C_TAB[r.mhdg] * r.mdist).round + r.morgx
	  r.my = (S_TAB[r.mhdg] * r.mdist).round + r.morgy
	  show_explode r

	  @robs.each do |rr|
	    next if rr.nil? || rr.status == false
	    d = hypot(r.mx - rr.x, r.my - rr.y)
	    if d < DIA[3]
	      if d < DIA[0]
		rr.cdamage += HIT[0]
	      elsif d < DIA[1]
		rr.cdamage += HIT[1]
	      elsif d < DIA[2]
		rr.cdamage += HIT[2]
	      else
		rr.cdamage += HIT[3]
	      end
	      up_damage rr, rr.cdamage
	    end
	  end
	end
      end
      next if r.status == false
      if r.reload != 0
	r.reload -= 1
      end
      if r.cspeed > HEATSP
	r.cheat += ((r.cspeed - HEATSP) / HRATE).round + 1
	if r.cheat >= HEATMAX
	  r.cheat = HEATMAX
	  r.hflag = true
	  if r.dspeed > HEATSP
	    r.dspeed = HEATSP
	  end
	end
      else
	if r.hflag != 0 || r.cheat > 0
	  r.cheat += COOLING
	  if r.cheat <= 0
	    r.hflag = false
	    r.cheat = 0
	  end
	end
      end
      if r.btemp
	r.btemp += CANCOOL
	r.btemp = 0 if r.btemp < 0
      end
      if r.cspeed != r.dspeed
	if r.cspeed > r.dspeed
	  r.cspeed -= ACCEL
	  if r.cspeed < r.dspeed
	    r.cspeed = r.dspeed
	  end
	else
	  r.cspeed += ACCEL
	  if r.cspeed > r.dspeed
	    r.cspeed = r.dspeed
	  end
	end
      end
      if r.hdg != r.dhdg
	mrate = RATE[(r.cspeed/25).to_i]
	d1 = (r.dhdg - r.hdg + 360) % 360
	d2 = (r.hdg - r.dhdg + 360) % 360
	d = (d1 < d2) ? d1 : d2
	if d < mrate
	  r.hdg = r.dhdg
	else
	  r.hdg = ((r.hdg.__send__ r.dir, mrate)+360)%360
	end
	r.orgx = r.x
	r.orgy = r.y
	r.range = 0
      end
      if r.cspeed > 0
	r.range = r.range + (r.cspeed * SP / 100)
	r.x = (C_TAB[r.hdg] * r.range + r.orgx).round
	r.y = (S_TAB[r.hdg] * r.range + r.orgy).round
	if r.x < 0 || r.x > 999
	  r.x = (r.x < 0) ? 0 : 999
	  r.orgx, r.orgy = r.x, r.y
	  r.range, r.cspeed, r.dspeed = 0, 0, 0
	  r.cdamage += COLL
	  up_damage r, r.cdamage
	end
	if r.y < 0 || r.y > 999
	  r.y = (r.y < 0) ? 0 : 999
	  r.orgx, r.orgy = r.x, r.y
	  r.range, r.cspeed, r.dspeed = 0, 0, 0
	  r.cdamage += COLL
	  up_damage r, r.cdamage
	end
      end
    end
      
    @robs.each do |r|
      next if r.nil?
      if r.status
	if r.cdamage >= 100
	  r.status = false
	  r.cdamage = 100
	  up_damage r, r.cdamage
	  disable_robot r, 1
	else
	  num_rob += 1
	end
      end
    end

    if num_rob <= 1
      @stop = true
      (0...MAX_ROBOTS).each do |i|
	next if @robs[i].nil?
	r = @robs[i]
	@robs[i] = nil
	notify_observers "win", i, r.cdamage
	r.kill "Winner! at tick:#{@ticks}"
      end
    end
    show_robots
  end

private
  def disable_robot(r, taunt)
    unless @robs[r.idnum].nil?
      @robs[r.idnum] = nil
      r.kill "dead at tick:#{@ticks}"
    end
  end

  def show_scan(r, deg, res)
    x, y = r.x, r.y
    d0 = deg - res / 2
    d0 += 360 if d0 < 0
    d1 = deg + res / 2
    d1 -= 360 if d1 >= 360
    x1 = (C_TAB[d0] * 700 + x).round
    x2 = (C_TAB[d1] * 700 + x).round
    y1 = 1000 - (S_TAB[d0] * 700 + y).round
    y2 = 1000 - (S_TAB[d1] * 700 + y).round
    y = 1000 - y
    notify_observers "scan", r.idnum, x, y, x1, y1, x2, y2
  end

  def show_explode(r)
    p "explode #{r}" if $DEBUG
    x, y = r.mx, 1000 - r.my
    notify_observers "explode", r.idnum, x, y
  end

  def show_robots
    @robs.each do |r|
      next if r.nil?
      if r.status
        x, y = r.x, 1000 - r.y
	notify_observers "robot", r.idnum, x, y
      end
      if r.mstate
        x, y = r.mx, 1000 - r.my
	notify_observers "missile", r.idnum, x, y
      end
    end
  end

  def up_damage(r, d)
    if d >= 100
      txt = "dead"
    else
      txt = "#{d}%"
    end
    p "#{r} = #{txt}" if $DEBUG
    notify_observers "damage", r.idnum, txt, d
  end

  def show_newrobot(r)
    notify_observers "newrobot", r.idnum, r.num
  end

end

class Creator
  include DRbUndumped
  def initialize(field)
    @fld = field
  end

  def join(ctrl, name)
    return nil if @fld.running
    r = @fld.add_robot ctrl, name
    p "join new Robots:#{name} #{(r.nil?)?'Rejected':''}" if $DEBUG
    r
  end

  if __FILE__ == $0
    def start(cv)
      @fld.do_start cv
    end

    def stop(cv)
      @fld.do_stop cv
    end

    def initNew(cv)
      @fld.do_initNew cv
    end

    def shutdown(cv)
      @fld.do_shutdown cv
      Thread.start do
        puts "waiting shutdown..."
	sleep 5
	DRb.stop_service
      end
    end

    def add_canvas(canvas)
      @fld.add_observer canvas
    end

    def del_canvas(canvas)
      @fld.delete_observer canvas
    end

  end

end

if __FILE__ == $0
  field = BattleField.new
  DRb.start_service('druby://:6852', Creator.new(field))
  puts DRb.uri
  DRb.thread.join
end

