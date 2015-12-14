=begin
 Copyright(c) 2001 arton
== ACKNOWLEDGMENTS
  I've used many ideas, architecture, and codes from 
    Mr. Tom Poindexter (tpoindex@nyx.net)'s TclRobots.
  This is almost TclRobots Ruby port except for using ORPC.
=end

require 'thread'
require 'drb/drb'
begin
  require 'drb/eq'
rescue LoadError
  class DRbObject
    def __drburi
      @uri
    end
    def ==(other)
      return false unless DRbObject === other
      (@ref == other.__drbref) && (@uri == other.__drburi)
    end
  end
end
require 'observer'
include Math

srand((($$ * 65277 + 13849) % 65536 + 65536) % 65536)
D2R = 180/PI
S_TAB, C_TAB = Array.new(360), Array.new(360)
(0...360).each do |i|
  S_TAB[i] = sin(i/D2R)
  C_TAB[i] = cos(i/D2R)
end

def hypot(x, y)
  sqrt(x ** 2 + y ** 2)
end

class Point
  def initialize(a)
    @x, @y = a
  end

  attr_accessor :x, :y
  
  def -(other)
    return @x - other.x, @y - other.y
  end

  def ==(other)
    return false unless Point === other
    @x == other.x && @y == other.y
  end

  def towin
    return @x, 1000 - @y
  end
end

class Moveable
  def initialize(a = [0,0], hdg = 0)
    @cur = Point.new(a)
    @org = Point.new(a)
    @hdg, @range = hdg, 0
  end
  attr_reader :cur, :org
  attr_accessor :range, :hdg

  def pos
    return @cur.x, @cur.y
  end

  def initnew(pnt, deg)
    @cur, @org, @hdg, @range = pnt.cur.dup, pnt.cur.dup, deg, 0
  end

  def hypot(other)
    sqrt((@cur.x - other.cur.x)**2 + (@cur.y - other.cur.y)**2)
  end

  def move(deg)
    @cur.x = (C_TAB[@hdg] * deg + @org.x).round
    @cur.y = (S_TAB[@hdg] * deg + @org.y).round
  end
end

class Missile < Moveable
  def initialize
    @dist = 0
    super
  end

  def fire(pnt, deg, rng)
    @dist = rng
    initnew pnt, deg
  end

  def update(spd)
    @range += spd
    move @range
  end

  def explode
    move @dist
  end

  def explode?
    @range > @dist
  end
end

class Motor < Moveable
  RATE = [90, 60, 40, 30, 20]
  HRATE = 10
  HEATSP = 35
  HEATMAX = 200
  TURN = [100, 50, 30, 20]
  ACCEL = 10
  SP = 10
  COOLING = -25
  COLL = 5

  def initialize(a = [0,0], hdg = 0)
    super
    @dhdg = @hdg
    @dir, @speed, @dspeed = '+', 0, 0
    @heat, @overheat = 0, false
    @dirty = true
  end

  attr_reader :speed, :heat, :overheat, :dirty

  def drive(deg, spd)
    d1 = (@hdg - deg + 360) % 360
    d2 = (deg - @hdg + 360) % 360
    d = (d1 < d2) ? d1 : d2

    @dhdg = deg
    @dspeed = (@overheat && spd > HEATSP) ? HEATSP : spd
    idx = (d / 25).to_i
    idx = 3 if idx > 3
    if @speed > TURN[idx]
      @dspeed = 0
      @dhdg = @hdg
    else
      @org = @cur.dup
      @range = 0
    end
    if (@hdg + d + 360) % 360 == deg
      @dir = '+'
    else
      @dir = '-'
    end
    @dspeed
  end

  def adjust
    if @speed > HEATSP
      @heat += ((@speed - HEATSP) / HRATE).round + 1
      if @heat >= HEATMAX
	@heat = HEATMAX
	@overheat = true
	if @dspeed > HEATSP
	  @dspeed = HEATSP
	end
      end
    else
      if @overheat || @heat > 0
	@heat += COOLING
	if @heat <= 0
	  @overheat = false
	  @heat = 0
	end
      end
    end
  end

  def accelate
      @speed != @dspeed
    if @speed > @dspeed
      @speed -= ACCEL
      @speed = @dspeed if @speed < @dspeed
    else
      @speed += ACCEL
      @speed = @dspeed if @speed > @dspeed
    end
  end
  
  def stabilize
    if @hdg != @dhdg
      mrate = RATE[(@speed/25).to_i]
      d1 = (@dhdg - @hdg + 360) % 360
      d2 = (@hdg - @dhdg + 360) % 360
      d = (d1 < d2) ? d1 : d2
      if d < mrate
	@hdg = @dhdg
      else
	@hdg = ((@hdg.__send__ @dir, mrate)+360)%360
      end
      @org = @cur.dup
      @range = 0
    end
  end

  def do_drive
    damage = 0
    if @speed > 0
      @range += (@speed * SP / 100)
      move @range
      @dirty = @cur != @org
      if @cur.x < 0 || @cur.x > 999
	@cur.x = (@cur.x < 0) ? 0 : 999
	@org = @cur.dup
	@range, @speed, @dspeed = 0, 0, 0
	damage = COLL
      end
      if @cur.y < 0 || @cur.y > 999
	@cur.y = (@cur.y < 0) ? 0 : 999
	@org = @cur.dup
	@range, @speed, @dspeed = 0, 0, 0
	damage = COLL
      end
    end
    damage
  end

end

class Robot
  include DRbUndumped

  CANHEAT = 20
  CANCOOL = -1
  MISMAX = 700
  MSP = 100
  CLIP = 4
  MRELOAD = ((MISMAX / MSP) + 0.5).round
  LRELOAD = MRELOAD * 3
  ERRDIST = 10
  SCANBAD = 35

  attr_reader :alive
  attr_reader :name
  attr_reader :idnum
  attr_reader :num

  attr_accessor :cdamage

  attr_reader :motor
  attr_accessor :mstate 
  attr_reader :missile

  def initialize(fld, ctrl, name, idx, quad)
    @alive = true
    @fld, @controller = fld, ctrl
    @name, @idnum = name, idx
    @num = ("#{name}#{idx}".hash % 65536).abs
    @motor = Motor.new(quad, rand(360))
    @cdamage = 0
    @sig = [0, 0]
    @mstate, @reload, @mused = false, 0, 0
    @missile = Missile.new
    @btemp = 0
    p self if $DEBUG
  end

  def scanner(deg, res)
    do_wait 2
    return 0 unless @alive
    return 0 if @fld.disabled?
    return -1 if deg < 0 || deg > 359
    return -1 if res < 0 || res > 10

    @fld.do_scanner(@idnum, deg, res)
  end

  def dsp
    do_wait
    return *@sig
  end

  def cannon(deg, rng)
    do_wait
    p "cannon #{@alive}, #{mstate}, #{@reload}" if $DEBUG
    return 0 if !@alive || @mstate || @reload != 0
    return 0 if @fld.disabled?
    return -1 if deg < 0 || deg > 359 || rng < 0 || rng > MISMAX
    @missile.fire @motor, deg, rng
    @mstate = true
    
    @btemp += CANHEAT
    @mused += 1
    if @mused == CLIP
      @reload = LRELOAD
      @mused = 0
    else
      @reload = MRELOAD
    end
    1
  end

  def drive(deg, spd)
    do_wait
    return 0 unless @alive
    return 0 if @fld.disabled?
    return -1 if deg < 0 || deg > 359 || spd < 0 || spd > 100

    @motor.drive deg, spd
  end

  def damage
    return 100 unless @alive
    do_wait
    @cdamage
  end

  def speed
    return 0 unless @alive
    do_wait
    @motor.speed
  end

  def loc
    do_wait
    @motor.pos
  end

  def tick
    @fld.ticks
  end

  def heat
    return @motor.overheat, @motor.heat
  end

  def kill(s)
    Thread.start do
      @controller.kill s
    end
  end

  def start
    @controller.start
  end

  def stop
    @controller.stop
  end

  def pos
    @motor.pos
  end

  def winpos
    @motor.cur.towin
  end

  def winmpos
    @missile.cur.towin
  end

  def update_missile
    @missile.update MSP
  end

  def explode?
    return false unless @missile.explode?
    @mstate = false
    @missile.explode
    true
  end

  def burned?(other)
    d = @motor.hypot(other.missile)
    [[6, 25], [10, 12], [20, 7], [50, 3]].each do |dia, hit|
      if d < dia
	@cdamage += hit
	return true
      end
    end
    false
  end

  def check_motor
    @motor.adjust
    @motor.accelate
    @motor.stabilize
    dmg = @motor.do_drive
    if dmg > 0
      @cdamage += dmg
      return true
    end
    false
  end

  def check_scanner
    if @btemp > 0
      @btemp += CANCOOL
      @btemp = 0 if @btemp < 0
    end
  end

  def check_cannon
    @reload -= 1 if @reload != 0
  end

  def check_scan(rob, deg, res, near)
    x, y = distance(rob)
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
	near = eval "#{dist} #{fud1} #{terr} #{fud2} #{@btemp}"
	near = 1 if near < 1
	return true, near
      end
    end
    return false, near
  end

  def set_sig(dsp, dmg)
    if @btemp >= SCANBAD
      @sig.fill 0
      return false
    else
      @sig[0..1] = dsp, dmg
    end
    true
  end

  def moved?
    @motor.dirty
  end

  def dead?
    return false if @cdamage < 100
    @alive, @cdamage = false, 100
    true
  end

private
  def do_wait(c = 1)
    sleep 0.2 * c
  end

  def distance(other)
    return @motor.cur - other.motor.cur
  end

end

class BattleField
  include Observable

  MAX_ROBOTS = 4

  TICK = 500
  QUADS = [[100, 100], [600, 100], [100, 600], [600, 600]]

  attr_reader :running
  attr_reader :ticks

  def initialize()
    @canvas = Hash.new
    @robs = Array.new(MAX_ROBOTS)
    @ticks = 0
    @mutex = Mutex.new
    @quads = QUADS.dup
    @update, @stop, @running = false, false, false
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
	observer.update ["newrobot", @robs[i].idnum, @robs[i].num]
      end
    end
    count_observers
  end

  def notify_observers(*arg)
    if @th.nil?
      @update = true
      @th = Thread.new do
	while @update
	  ag = @q.pop
	  changed
	  a = [ag]
	  until @q.empty? || a.size > 12
	    a << @q.pop
	  end
	  super *a
	end
      end
    end
    @q.push arg
  end

  def notify_otherobservers(ob, *arg)
    changed
    if defined? @observer_state and @observer_state
      if defined? @observer_peers
	@observer_peers.each do |i|
	  next if ob == i
	  i.update arg
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
    rob = @robs[robot]
    return 0 if rob.nil?
    show_scan rob, deg, res
    dsp, dmg, near = 0, 0, 9999
    @robs.each do |robx|
      next if (robx.nil? || robx == rob || !robx.alive)
      t, near = robx.check_scan(rob, deg, res, near)
      if t
	dsp = robx.num
	dmg = robx.cdamage
      end
    end
    if rob.set_sig(dsp, dmg)
      return near unless (near == 9999)
    end
    0
  end

  def disabled?
    @stop || @running == false
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
    @update = false
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
	r.update_missile
	if r.explode?
	  show_explode r
	  @robs.each do |rr|
	    next if rr.nil? || rr.alive == false
	    if rr.burned?(r)
	      up_damage rr
	    end
	  end
	end
      end
      next if r.alive == false
      r.check_cannon
      r.check_scanner
      if r.check_motor
	up_damage r
      end
    end
    @robs.each do |r|
      next if r.nil? || r.alive == false
      if r.dead?
	up_damage r
	disable_robot r
      else
	num_rob += 1
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
  def disable_robot(r)
    unless @robs[r.idnum].nil?
      @robs[r.idnum] = nil
      r.kill "dead at tick:#{@ticks}"
    end
  end

  def show_scan(r, deg, res)
    x, y = r.pos
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
    notify_observers "explode", r.idnum, *r.winmpos
  end

  def show_robots
    @robs.each do |r|
      next if r.nil?
      if r.alive && r.moved?
	notify_observers "robot", r.idnum, *r.winpos
      end
      if r.mstate
	notify_observers "missile", r.idnum, *r.winmpos
      end
    end
  end

  def up_damage(r)
    if r.cdamage >= 100
      txt = "dead"
    else
      txt = "#{r.cdamage}%"
    end
    p "#{r} = #{txt}" if $DEBUG
    notify_observers "damage", r.idnum, txt, r.cdamage
  end

  def show_newrobot(r)
    notify_observers "newrobot", r.idnum, r.num
  end

end

class RobotOffice
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
      nil
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
  DRb.start_service('druby://:6852', RobotOffice.new(field))
  puts DRb.uri
  DRb.thread.join
end

