-- Most of the code here was taken from https://github.com/deficient/volume-control.git
-- and its author reserved the rights for this code.
--
-- Modified this widget so that it has a different icon
-- 
-- Volume Control
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local cairo = require("lgi").cairo

-- compatibility fallbacks for 3.5:
local timer = gears.timer or timer
local spawn = awful.spawn or awful.util.spawn
local watch = awful.spawn and awful.spawn.with_line_callback

local dpi = require('beautiful').xresources.apply_dpi

------------------------------------------
-- Private utility functions
------------------------------------------

local function readcommand(command)
    local file = io.popen(command)
    local text = file:read('*all')
    file:close()
    return text
end

local function quote_arg(str)
    return "'" .. string.gsub(str, "'", "'\\''") .. "'"
end

local function table_map(func, tab)
    local result = {}
    for i, v in ipairs(tab) do
        result[i] = func(v)
    end
    return result
end

local function make_argv(args)
    return table.concat(table_map(quote_arg, args), " ")
end

local function substitute(template, context)
  if type(template) == "string" then
    return (template:gsub("%${([%w_]+)}", function(key)
      return tostring(context[key] or "default")
    end))
  else
    -- function / functor:
    return template(context)
  end
end

local function new(self, ...)
    local instance = setmetatable({}, {__index = self})
    return instance:init(...) or instance
end

local function class(base)
    return setmetatable({new = new}, {
        __call = new,
        __index = base,
    })
end

------------------------------------------
-- Volume control interface
------------------------------------------

local vcontrol = class()

function vcontrol:init(args)
    self.callbacks = {}
    self.cmd = "amixer"
    self.device = args.device or nil
    self.cardid  = args.cardid or nil
    self.channel = args.channel or "Master"
    self.step = args.step or '5%'

    self.timer = timer({ timeout = args.timeout or 0.5 })
    self.timer:connect_signal("timeout", function() self:get() end)
    self.timer:start()

    if args.listen and watch then
        self.listener = watch({'stdbuf', '-oL', 'alsactl', 'monitor'}, {
          stdout = function(line) self:get() end,
        })
        awesome.connect_signal("exit", function()
            awesome.kill(self.listener, awesome.unix_signal.SIGTERM)
        end)
    end
end

function vcontrol:register(callback)
    if callback then
        table.insert(self.callbacks, callback)
    end
end

function vcontrol:action(action)
    if self[action]                   then self[action](self)
    elseif type(action) == "function" then action(self)
    elseif type(action) == "string"   then spawn(action)
    end
end

function vcontrol:update(status)
    local volume = status:match("(%d?%d?%d)%%")
    local state  = status:match("%[(o[nf]*)%]")
    if volume and state then
        local volume = tonumber(volume)
        local state = state:lower()
        local muted = state == "off"
        for _, callback in ipairs(self.callbacks) do
            callback(self, {
                volume = volume,
                state = state,
                muted = muted,
                on = not muted,
            })
        end
    end
end

function vcontrol:mixercommand(...)
    local args = awful.util.table.join(
      {self.cmd},
      (self.cmd == "amixer") and {"-M"} or {},
      self.device and {"-D", self.device} or {},
      self.cardid and {"-c", self.cardid} or {},
      {...})
    return readcommand(make_argv(args))
end

function vcontrol:get()
    self:update(self:mixercommand("get", self.channel))
end

function vcontrol:up()
    self:update(self:mixercommand("set", self.channel, self.step .. "+"))
end

function vcontrol:down()
    self:update(self:mixercommand("set", self.channel, self.step .. "-"))
end

-- amixer can be wrong regarding the device to be muted, and even it can
-- can communicate to pavucontrol to ask it, it does a shitty job in it and
-- all sinks are simply muted. This won't do, use pavucontrol command to toggle
-- instead
function vcontrol:pavucontrol_toggle()
	return readcommand("pactl set-sink-mute alsa_output.pci-0000_00_1f.3.analog-stereo toggle")
end
function vcontrol:toggle()
	--self:pavucontrol_toggle()
    self:update(self:mixercommand("set", self.channel, "toggle"))
end
--function vcontrol:toggle()
	--self:pavucontrol_toggle()
    --self:update(self:mixercommand("get", self.channel))
--end

function vcontrol:mute()
    self:update(self:mixercommand("set", "Master", "mute"))
end

function vcontrol:unmute()
    self:update(self:mixercommand("set", "Master", "unmute"))
end

function vcontrol:list_sinks()
    local sinks = {}
    local sink
    for line in io.popen("env LC_ALL=C pactl list sinks"):lines() do
        if line:match("Sink #%d+") then
            sink = {}
            table.insert(sinks, sink)
        else
            local k, v = line:match("^%s*(%S+):%s*(.-)%s*$")
            if k and v then sink[k:lower()] = v end
        end
    end
    return sinks
end

function vcontrol:set_default_sink(name)
    os.execute(make_argv{"pactl set-default-sink", name})
end

------------------------------------------
-- Volume control widget
------------------------------------------

-- derive so that users can still call up/down/mute etc
local vwidget = class(vcontrol)

function vwidget:init(args)
    vcontrol.init(self, args)

	self.lclick = args.lclick or "toggle"
	self.mclick = args.mclick or "pavucontrol"
	self.rclick = args.rclick or self.show_menu

	self.font = args.font        or nil
	self.widget = args.widget    or (self:create_widget(args)  or self.widget)
	self.tooltip = args.tooltip and (self:create_tooltip(args) or self.tooltip)

	self:register(args.callback or self.update_widget)
	self:register(args.tooltip and self.update_tooltip)

	self.widget:buttons(awful.util.table.join(
		awful.button({}, 1, function() self:action(self.lclick) end),
		awful.button({}, 2, function() self:action(self.mclick) end),
		awful.button({}, 3, function() self:action(self.rclick) end),
		awful.button({}, 4, function() self:up() end),
		awful.button({}, 5, function() self:down() end)
	))

	self:get()
end

-- text widget
function vwidget:create_widget(args)

	local img_widget = wibox.widget
	{
		widget = wibox.widget.imagebox,
		resize = true,
	}

	local sink_img = wibox.widget
	{
		widget = wibox.widget.imagebox,
		resize = true,
	}

	local widget = wibox.widget.base.make_widget_declarative {
		img_widget,
		sink_img,
		spacing = dpi(4),
		layout = wibox.layout.fixed.horizontal,
	}

	local headphones_img = cairo.ImageSurface.create(cairo.Format.ARGB32, 98, 138.959)
	-- set the source 
	self.is = gears.surface(string.gsub("~/.config/awesome/volume-control/headphones.png", "~", os.getenv("HOME")))
	local cr  = cairo.Context(headphones_img)
	-- draw the note symbol on the canvas
	cr:set_source_surface(self.is, 0, 0)
	cr:paint()
	sink_img:set_image(headphones_img)

	self.widget = widget
	self.img_widget = img_widget
	self.sink_img = sink_img
	self.headphones_img = headphones_img

	self.state_imgs = {}
end

function vwidget:create_menu()
    local sinks = {}
    --for i, sink in ipairs(self:list_sinks()) do
        --table.insert(sinks, {sink.description, function()
            --self:set_default_sink(sink.name)
        --end})
    --end
	for _, sink in ipairs({ "computer", "headphones"}) do
        table.insert(sinks, {sink, function() 
        end})
	end

    return awful.menu { items = {
        { "mute", function() self:mute() end },
        { "unmute", function() self:unmute() end },
        { "Default Sink", sinks },
        { "pavucontrol", function() self:action("pavucontrol") end },
    } }
end

function vwidget:show_menu()
    if self.menu then
        self.menu:hide()
    else
        self.menu = self:create_menu()
        self.menu:show()
        self.menu.wibox:connect_signal("property::visible", function()
            self.menu = nil
        end)
    end
end

function vwidget:get_volume_image(setting)
	
	local range = setting.volume == 0 and 0 or setting.volume // (100 / 30) + 1
	local widget_img_path = string.gsub("~/.config/awesome/volume-control/drawing.png", "~", os.getenv("HOME"))

	if not self.state_imgs[range] then

		self.state_imgs[range] = {}

		-- Draw the picture for unmuted case

		-- create an empty canvas
		local unmuted_img = cairo.ImageSurface.create(cairo.Format.ARGB32, 98, 138.959)

		-- set the source 
		self.is = gears.surface(widget_img_path)
		local cr  = cairo.Context(unmuted_img)

		-- draw the note symbol on the canvas
		cr:set_source_surface(self.is, 0, -140 * range)
		cr:paint()

		self.state_imgs[range][false] = unmuted_img


		-- Draw the picture for muted case. This draws the same
		-- picture but draw a line (which is also within the
		-- drawing.png picture) over the original picture


		local muted_img = cairo.ImageSurface.create(cairo.Format.ARGB32, 98, 138.959)

		-- set the source
		cr  = cairo.Context(muted_img)
		cr:set_source_surface(self.is, 0, -140 * range)
		cr:paint()

		-- paint the red line over the painting
		cr:set_source_surface(self.is, -98, 0)
		cr:paint()

		self.state_imgs[range][true] = muted_img

	end

	return self.state_imgs[range][setting.muted]
end

function vwidget:update_widget(setting)
    --self.widget:set_markup(
        --self.widget_text[setting.state]:format(setting.volume))
	command = string.gsub("bash -c ~/.config/awesome/volume-control/get_sink.sh", "~", os.getenv("HOME"))
	local default_sink = readcommand(command)

	--print("default sink is", default_sink)

	if default_sink == "h\n" then
		self.sink_img:set_image(self.headphones_img)
	else
		self.sink_img:set_image(nil)
	end

	self.img_widget:set_image(self:get_volume_image(setting))
end

-- tooltip
function vwidget:create_tooltip(args)
    self.tooltip_text = args.tooltip_text or [[
Volume: ${volume}% ${state} ]]
    self.tooltip = args.tooltip and awful.tooltip{objects={self.img_widget},
                                                  bg="#3c3851",
                                                  mode="outside"}
end

function vwidget:update_tooltip(setting)
    self.tooltip:set_text(substitute(self.tooltip_text, {
        volume  = setting.volume,
        state   = setting.state,
    }))
end

-- provide direct access to the control class
vwidget.control = vcontrol
return vwidget
