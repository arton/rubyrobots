require 'vr/vruby'
require 'vr/vrcontrol'
require 'drb/drb'

if ARGV.size != 1
  puts "usage: rubyrobot.rb rubyot_uri"
  exit 1
end

class Rect
  attr_accessor :l
  attr_accessor :t
  attr_accessor :r
  attr_accessor :b
  attr_accessor :c
  def initialize(l, t, r, b, c)
    @l, @t, @r, @b, @c = l, t, r, b, c
  end
end

  WHITE=RGB(0xff,0xff,0xff)
  BLACK=RGB(0,0,0)
  RED=RGB(0xff,0,0)
  BLUE=RGB(0,0,0xff)
  GREEN=RGB(0,0x80,0)
  ORANGE=RGB(0xe0, 0x80, 0x40)
  YELLOW=RGB(0xff, 0xff, 0)
  GRAY = RGB(0xc0, 0xc0, 0xc0)
  ROBOC = [RED, BLUE, GREEN, YELLOW]

class RubyotCanvas < VRCanvasPanel
  include DRbUndumped

  def init
    @robots = Array.new(4)
    @missile = Array.new(4)
    clearCanvas
  end

  def clearCanvas
    @canvas.setBrush(GRAY)
    @canvas.setPen(GRAY)
    @canvas.fillRect(0, 0, w, h)
    refresh false
  end

  def update(*arg)
    Thread.critical = true
    arg.each do |a|
      __send__ 'show_' + a.shift, *a
    end
    Thread.critical = false
  end

private

  def show_newrobot(rob, name)
    parent.newrobot rob, name
  end

  def show_scan(rob, x, y, x1, y1, x2, y2)
    a = [x/2, y/2, x1/2, y1/2, x2/2, y2/2]
    draw_scanner ROBOC[rob], *a
    draw_scanner GRAY, *a
  end

  def show_explode(rob, x, y)
    l, t, r, b = x / 2, y / 2, x / 2 + 3, y / 2 + 3
    m = @missile[rob]
    unless m.nil?
      del_rect m
      @missile[rob] = nil
    end
    [[RED, 0], [ORANGE, 4], 
     [YELLOW, 8], [GRAY, 8]].each do |c, a|
      draw_explode c, a, l, t, r, b
    end
  end

  def show_robot(rob, x, y)
    l, t, r, b = x / 2, y / 2, x / 2 + 6, y / 2 + 6
    rcold = @robots[rob]
    rc = Rect.new(l, t, r, b, ROBOC[rob])
    unless rcold.nil?
      del_rect rcold
    end
    @robots[rob] = rc
    show_rect rc, rc.c
  end

  def show_missile(rob, x, y)
    l, t, r, b = x / 2, y / 2, x / 2 + 3, y / 2 + 3
    mold = @missile[rob]
    m = Rect.new(l, t, r, b, BLACK)
    unless mold.nil?
      del_rect mold
    end
    @missile[rob] = m
    show_rect m, BLACK
  end

  def show_damage(rob, txt, dmg)
    parent.dputs rob, txt
    puts txt
  end

  def show_win(rob, d)
    parent.dputs rob, "Win!"
    parent.initgame
  end

  def show_start
    parent.start
  end

  def show_stop
    parent.stop
  end

  def show_initNew
    parent.initNew
  end

  def show_close
    parent.close
  end

  def draw_scanner(c, px, py, px1, py1, px2, py2)
    @canvas.setPen(c)
    @canvas.drawLine px, py, px1, py1
    if px1 != px2 || py1 != py2
      @canvas.drawLine px, py, px2, py2
    end
    if c != GRAY
      refresh false
    end
  end

  def draw_explode(c, o, l, t, r, b)
    @canvas.setBrush(c == GRAY ? GRAY : RED)
    @canvas.setPen(c)
    @canvas.fillEllipse(l - o, t - o, r + o, b + o)
    if c != GRAY
      refresh false
      sleep 0.2
    end
  end

  def del_rect(r)
    @canvas.setBrush(GRAY)
    @canvas.setPen(GRAY)
    @canvas.fillRect(r.l, r.t, r.r, r.b)
  end

  def show_rect(r, c)
    @canvas.setBrush(c)
    @canvas.setPen(c)
    @canvas.fillRect(r.l, r.t, r.r, r.b)
    refresh false
  end

end

class RubyotForm < VRForm

  def construct
    self.caption = "RubyRobots"
    addControl RubyotCanvas, "canvas", "", 0, 0, 503, 503
    @canvas.createCanvas 504, 504
    @canvas.init
    (0..3).each do |i|
      x = (i % 2) * 200 + 100
      y = (i > 1) ? 540 : 510
      addControl VRCanvasPanel, "cv#{i}", "", x, y, 8, 22
      eval "@cv#{i}.createCanvas 10,22,#{ROBOC[i]}"
      addControl VRStatic, "lbName#{i}", "----", x+10, y, 60, 22
      addControl VRStatic, "lb#{i}", "", x+70, y, 100, 22
    end
    @close = false

    DRb.start_service
    @robots = DRbObject.new(nil, ARGV[0])
    @robots.add_canvas @canvas
    addControl VRButton, "btnRun", "START", 10, 510, 80, 24
    addControl VRButton, "btnQuit", "QUIT", 10, 540, 80, 24

  end

  def newrobot(rob, name)
    eval "@lbName#{rob}.caption = \'##{name}\'"
  end

  def dputs(rob, s)
    eval "@lb#{rob}.caption = \'#{s}\'"
  end

  def initgame
    @btnRun.caption = "NEW"
    @btnRun.enabled = true
  end

  def start
    @btnRun.enabled = false
  end

  def stop
    @btnRun.caption = "START"
  end

  def initNew
    screenInit
    @btnRun.caption = "START"
  end

  def btnRun_clicked
    if @btnRun.caption == "START"
      unless @robots.start(@canvas)
	messageBox "Isolate Robot"
      else
	@btnRun.enabled = false
      end
    elsif @btnRun.caption == "NEW"
      screenInit
      @robots.initNew @canvas
      @btnRun.caption = "START"
    else
      @robots.stop @canvas
      @btnRun.caption = "START"
    end
  end

  def btnQuit_clicked
    @close = true
  end

  def loop
    until @close do
      Thread.critical = true
      SWin::Application.doevents
      Thread.critical = false
      unless alive?
	break  
      end
      sleep 0.2
    end
    @robots.del_canvas @canvas
    puts "call shutdown.."
    @robots.shutdown @canvas
    close if alive? 
  end

private
  def screenInit
    @canvas.clearCanvas
    (0..3).each do |i|
      eval "@lbName#{i}.caption = \'----\'"
      eval "@lb#{i}.caption = \'\'"
    end
  end

end

frm = VRLocalScreen.showForm(RubyotForm, rand(100), rand(100), 512, 600)
frm.loop

