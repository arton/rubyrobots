require 'tk'
require 'drb/drb'
require 'tkclass'

include Math

USE_AFTER = false
NO_SCANNER = false
MOVE_TICK = 4

class RubyotCanvas
  include DRbUndumped
  include Tk

  ROBOC = ['red', 'blue', 'green', 'yellow']
  EXPC = ['yellow', 'orange', 'red']

  IDLE = 0
  START = 1
  WAIT = 3

  def initialize(w, h)
    @canvas = Canvas.new(nil,
			 'width'=>w, 
			 'height'=>h,
			 'borderwidth'=>1,
			 'relief'=>'sunken')
    @canvas.pack
    @win0, @win, @rel, @lb, @lbName = [], [], [], [], []
    @robo = Array.new(4)
    @tick = Array.new(4).fill(0)
    @missile = Array.new(4)
    @scan = Array.new(4)
    (0..3).each do |i|
      if i % 2 == 0
	@win0[i / 2] = Frame.new(nil, 
				 'width'=>w,
				 'height'=>12)
	(i..i+1).each do |j|
	  @win[j] = Frame.new(@win0[i / 2],
			      'width'=>w / 2,
			      'height'=>12)
	end
	@win0[i / 2].pack 'fill'=>'x'
	@win[i].pack 'side'=>'left'
	@win[i + 1].pack
      end
      @rel[i] = Frame.new(@win[i],
			  'relief'=>'groove',
			  'height'=>8,
			  'width'=>16,
			    'background'=>ROBOC[i])
      @lbName[i] = Label.new(@win[i],
			     'text'=>'------')
      @lb[i] = Label.new(@win[i]
			 )
      @rel[i].pack 'side'=>'left'
      @lbName[i].pack 'side'=>'left'
      @lb[i].pack 'side'=>'right'
      @runstat = IDLE
    end

    DRb.start_service
    @robots = DRbObject.new(nil, ARGV[0])

    @runBtn = Button.new(nil, 'text'=>'START',
			 'command'=>proc {
			   case @runstat
			   when IDLE
			     unless @robots.start(self)
			       puts 'Isolate'
			     else
			       show_start
			     end
			   when START
			   else
			     @robots.initNew self
			     show_initNew
			   end
			 })
    @quitBtn = Button.new(nil, 'text'=>'QUIT',
			  'command'=>proc { 
			    @robots.shutdown self
			    after 500, proc{exit}
			  })
    @runBtn.pack('side'=>'left')
    @quitBtn.pack('side'=>'right')

    after 1000, proc{@robots.add_canvas self}
  end

  def update(*arg)
    arg.each do |a|
      __send__ 'show_' + a.shift, *a
    end
  end

private
  def show_newrobot(rob, name)
    @lbName[rob].text "##{name}"
  end

  def show_dputs(rob, s)
    puts "#{rob}=#{s}"
  end

  def show_scan(rob, x, y, x1, y1, x2, y2)
    return false if NO_SCANNER
    remove_scan rob unless USE_AFTER
    x /= 2
    y /= 2
    x1 /= 2
    x2 /= 2
    y1 /= 2
    y2 /= 2
    s0 = Line.new(@canvas,
		  x, y, x1, y1, 'fill'=>ROBOC[rob])
    if x1 != x2 || y1 != y2
      s1 = Line.new(@canvas,
		  x, y, x2, y2, 'fill'=>ROBOC[rob])
    else
      s1 = nil
    end
    @scan[rob] = [s0, s1]
    after 100, proc{remove_scan rob} if USE_AFTER
  end

  def remove_scan(rob)
    unless @scan[rob].nil?
      @scan[rob].each do |s|
	s.destroy unless s.nil?
      end
      @scan[rob] = nil
    end
  end

  def show_robot(rob, x, y)
    if @tick[rob] == 0
      remove_scan rob unless USE_AFTER
      @robo[rob].destroy unless @robo[rob].nil?
      @robo[rob] = Rectangle.new(@canvas,
		      x / 2, y / 2,
		      x / 2 + 6, y / 2 + 6,
		      'fill'=>ROBOC[rob])
      @tick[rob] += 1
    end
    if @tick[rob] > MOVE_TICK
      @tick[rob] = 0
    else
      @tick[rob] += 1
    end
  end

  def show_missile(rob, x, y)
    @missile[rob].destroy unless @missile[rob].nil?
    @missile[rob] = Rectangle.new(@canvas,
		      x / 2, y / 2,
		      x / 2 + 3, y / 2 + 3,
		      'fill'=>'black')
  end

  def show_explode(rob, x, y)
    @missile[rob].destroy unless @missile[rob].nil?
    @missile[rob] = nil
    x /= 2
    y /= 2
    o = 10
    exp = Array.new(3)
    (0..2).each do |i|
      o -= 3 * i
      exp[i] = Oval.new(@canvas, x-o, y-o, x+o, y+o,
			'fill'=>EXPC[i],
			'outline'=>EXPC[i])
    end
    after 200, proc{remove_explode *exp}
  end

  def remove_explode(e0, e1, e2)
    e0.destroy
    e1.destroy
    e2.destroy
  end

  def show_damage(rob, txt, dmg)
    @lb[rob].text txt
  end

  def show_win(rob, d)
    @runstat = WAIT
    @lb[rob].text 'Winner!'
    puts "#{rob}=Win!"
    @runBtn.text 'NEW'
  end

  def show_start
    @runstat = START
    @runBtn.text ''
  end

  def show_initNew
    @runstat = IDLE
    @runBtn.text 'START'
    (0..3).each do |i|
      @robo[i].destroy unless @robo[i].nil?
      @robo[i] = nil
      @missile[i].destroy unless @missile[i].nil?
      @missile[i] = nil
      remove_scan i
      @lbName[i].text ''
      @lb[i].text ''
    end
  end

  def show_close
    after 500, proc{exit}
  end

end

cv = RubyotCanvas.new 506, 506
cv.mainloop

