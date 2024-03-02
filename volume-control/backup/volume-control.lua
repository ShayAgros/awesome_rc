local wibox = require("wibox")
local awful = require("awful")
local filesystem = require("gears.filesystem")
local gears = require("gears")
local dpi = require('beautiful').xresources.apply_dpi
local cairo = require("lgi").cairo
local naughty = require('naughty')

local vol_backend = {}

local function conf_backend(device)
  local be
  if device == "pulse" then
    be = assert(require("volume-control.pulse_backend"))
  else
    error("volume-widget: backend can only be pulse for now")
  end

  return be
end

function vol_backend:query_default_sink()
  print("Running query")
  self.backend:query_default_sink_async(function(sink)
    if not sink then
      naughty.notify {
        title = "No default sink!",
        text = "Wasn't able to query default sink",
        timeout = 0
      }
      return
    end

    self.active_sink = sink
    self.frontend:update_widget(sink)
  end
  )
end

function vol_backend:list_sinks(cb_func)
  self.backend:query_sinks_async(cb_func)
end

function vol_backend:set_default_sink(sink_index)
  self.backend:set_default_sink(sink_index)
end

function vol_backend:modify_volume(amount)
  if not self.active_sink then
    error("No active sink identified")
    return
  end

  self.backend:modify_volume(self.active_sink, amount)
  --print("volume modify active sink voumes", self.active_sink.Volume.left, self.active_sink.Volume.right)
end

function vol_backend:toggle_mute()
  self.backend:toggle_mute()
end

function vol_backend:init(args)
  assert(args and args.frontend and args.frontend.update_widget,
    "Need to provide an object which implements update_widget function")

  self.engine = args.engine or "pulse"
  self.frontend = args.frontend
  self.backend = conf_backend(self.engine)

  self.step = 5
  local widget = self.frontend.widget
  if widget then
    widget:connect_signal("volume_up", function () self:modify_volume(self.step) end)
    widget:connect_signal("volume_down", function () self:modify_volume(-self.step) end)
    widget:connect_signal("toggle_mute", function () self:toggle_mute() end)
  end

  self.backend:set_event_listener(function () self:query_default_sink() end)
  self:query_default_sink()

  return self
end

local created_volume_widget
local vwidget = {}

function vwidget:init(args)
  args = args or {}

  -- this allows to get a widget that was previously initialized
  if args.get_existing_or_create and created_volume_widget then
    return created_volume_widget
  end

  self.engine = args.engine or "pulse"

  local config_dir = filesystem.get_configuration_dir()
  local module_dir = config_dir .. "/volume-control"
  self.extern_sink_icon = args.extern_sink_icon or module_dir .. "/imgs/headphones.png"
  print(self.extern_sink_icon)
  self.cache = {}
  self.cache.Volume = {}

  self:create_widget()

  self:create_mouse_control()

  -- Needs to be done after all GUI elements are configured
  self.backend = vol_backend:init {
    ["engine"] = self.engine,
    ["frontend"] = self
  }

  created_volume_widget = self.widget
  return self.widget
end

local function create_image(image_path, xcoor, ycoor)
  xcoor = xcoor or 0
  ycoor = ycoor or 0

  -- draw the volume image
  local image_surface = cairo.ImageSurface.create(cairo.Format.ARGB32, 98, 138.959)
  local cr  = cairo.Context(image_surface)
	-- draw the note symbol on the canvas
  local source_surface = gears.surface(image_path)
	cr:set_source_surface(source_surface, xcoor, ycoor)
	cr:paint()

  return image_surface
end

function vwidget:create_menu(cb_func)
  local sinks_manu_entries = {}

  self.backend:list_sinks(function(sinks)
    for _, sink in ipairs(sinks) do
      table.insert(sinks_manu_entries,
        { sink.Description[1], function()
          self.backend:set_default_sink(sink.number)
        end })
    end

    cb_func(awful.menu { items = sinks_manu_entries })
  end)
end

function vwidget:display_sink_options_menu()
  if self.menu then
    self.menu:hide()
  else
    self:create_menu(function (menu)
      self.menu = menu
      self.menu:show()
      self.menu.wibox:connect_signal("property::visible", function()
        self.menu = nil
      end)
    end)
  end
end

function vwidget:create_mouse_control()
	self.widget:buttons(awful.util.table.join(
		awful.button({}, 3, function()
      print("moused clicked")
      self:display_sink_options_menu() end)
	))
end

function vwidget:create_widget()

	local vol_widget = wibox.widget {
		widget = wibox.widget.imagebox,
		resize = true,
	}

	local sink_widget = wibox.widget {
		widget = wibox.widget.imagebox,
		resize = true,
	}

  sink_widget:set_image(create_image(self.extern_sink_icon))

	self.widget = wibox.widget.base.make_widget_declarative {
		vol_widget,
		sink_widget,
		spacing = dpi(4),
		layout = wibox.layout.fixed.horizontal,
	}

  self.vol_widget = vol_widget
  self.sink_widget = sink_widget
	self.state_imgs = {}
end

function vwidget:get_volume_image(volume, muted)
  local config_dir = filesystem.get_configuration_dir()
  local module_dir = config_dir .. "/volume-control"
	local widget_img_path = module_dir .. "/imgs/drawing.png"
	local range = volume == 0 and 0 or volume // (100 / 30) + 1

  print("volume range is", range)

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

	return self.state_imgs[range][muted]
end

function vwidget:update_widget(sink)
  if not self.widget then
    return
  end

  -- currently sink widget is only 'headphones'. Hide it if it's anything else
  if sink["Active Port"][1] == "analog-output-headphones" then
    self.sink_widget.visible = true
  else
    self.sink_widget.visible = false
  end

  -- update widget only if volume has changed
  --if self.cache.Volume.left ~= sink.Volume.left or
     --self.cache.Volume.right ~= sink.Volume.right then

    local vol = tonumber(sink.Volume.left)
    local muted = sink.Volume.muted
    self.vol_widget:set_image(self:get_volume_image(vol, muted))

    self.cache.Volume.left = sink.Volume.left
    self.cache.Volume.right = sink.Volume.right
  --end
end

function shayagr_volume_test_func()
  --print("output of awesome function")
  local _, spawn = pcall(require, "awful.spawn")
  local be = assert(dofile(gears.filesystem.get_configuration_dir() .. "/volume-control/pulse_backend.lua"))
  be:test_query_default_sink()

  spawn.with_shell("echo " .. "hi there" .. ">> /tmp/awesome_debug.txt")

  --return "hey there"
end

return setmetatable(vwidget, {__call = vwidget.init })
