local wibox = require("wibox")
local filesystem = require("gears.filesystem")
local gears = require("gears")
local dpi = require('beautiful').xresources.apply_dpi
local cairo = require("lgi").cairo
local timer = require("gears.timer")

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

function vol_backend:query_sinks()
  self.backend:query_sinks_async(function(sinks)
    if sinks and sinks.active then
      self.widget:update_widget(sinks.active)
    end
  end
  )
end

function vol_backend:init(args)
  assert(args.widget and args.widget.update_widget,
    "Need to provide an object which implements update_widget function")

  self.engine = args.engine or "pulse"
  self.widget = args.widget
  self.backend = conf_backend(self.engine)

  self.timer = timer({
    timeout = args.timeout or 0.5,
    callback = function() self:query_sinks() end })
  self.timer:start()

  return self
end

local vwidget = {}

function vwidget:init(args)
  args = args or {}

  self.backend = vol_backend:init {
    ["engine"] = self.engine,
    ["widget"] = self
  }

  local config_dir = filesystem.get_configuration_dir()
  local module_dir = config_dir .. "/volume-control"
  self.extern_sink_icon = args.extern_sink_icon or module_dir .. "/headphones.png"
  self.widget = self:create_widget()
  self.cache = {}
  self.cache.Volume = {}

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

function vwidget:create_widget()

	local vol_widget = wibox.widget
	{
		widget = wibox.widget.imagebox,
		resize = true,
	}

	local sink_widget = wibox.widget
	{
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
	local range = volume == 0 and 0 or volume // (100 / 30) + 1
	local widget_img_path = module_dir .. "/drawing.png"

	if not self.state_imgs[range] then

		self.state_imgs[range] = {}

		-- Draw the picture for unmuted case

		self.state_imgs[range][false] = create_image(widget_img_path, 0, -140 * range)

		-- Draw the picture for muted case. This draws the same
		-- picture but draw a line (which is also within the
		-- drawing.png picture) over the original picture

		local muted_img = cairo.ImageSurface.create(cairo.Format.ARGB32, 98, 138.959)

		-- set the source
		local cr  = cairo.Context(muted_img)
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
  -- currently sink widget is only 'headphones'. Hide it if it's anything else
  if sink["Active Port"] == "analog-output-headphones" then
    self.sink_widget.visible = true
  else
    self.sink_widget.visible = false
  end

  -- update widget only if volume has changed
  if self.cache.Volume.left ~= sink.Volume.left or
     self.cache.Volume.right ~= sink.Volume.right then

    -- TODO: add a fix for the case where volume.left and volume.right are
    -- different
    local vol = tonumber(sink.Volume.left)
    local muted = sink.Volume.muted
    self.vol_widget:set_image(self:get_volume_image(vol, muted))

    self.cache.Volume.left = sink.Volume.left
    self.cache.Volume.right = sink.Volume.right
  end
end

return setmetatable(vwidget, {__call = vwidget.init })
