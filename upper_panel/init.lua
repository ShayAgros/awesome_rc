local wibox = require('wibox')
local awful = require("awful")
local gears = require("gears")
local dpi = require('beautiful').xresources.apply_dpi
local beautiful = require('beautiful')
local tags_list = require('upper_panel.tags_list')
local task_list	= require('upper_panel.task_list')
local system_tray = require('upper_panel.system_tray')
local layout_box = require('upper_panel.layout_box')

local function tags_shape(cr, width, height)
	gears.shape.rounded_rect(cr, width, height, 6)
end

-- math.floor function is very important here. Passing fractions for widget
-- width would cause pixels not being displayed correctly
local upper_panel = function(s)

	local screen_width = s.geometry.width
	local screen_height = s.geometry.width

	local left_panel_width = math.floor(screen_width * 0.3)
	local center_panel_width = math.floor(screen_width * 0.3)
	local right_panel_systemtray_width = math.floor(screen_width * 0.2)

	local panel = awful.wibar {
		position	= "top",
		screen		= s,
		height		= dpi(40),
		bg			= '#00000000'
	}

	panel:setup {
		{
			-- Left panel
			{
				{
					{
						{
							widget = tags_list(s),
						},
						right	= math.floor(screen_width * 0.006),
						top		= dpi(1),
						widget	= wibox.container.margin,
					},
					bg		= beautiful.titlebar_bg_normal,
					widget	= wibox.container.background,
					shape	= tags_shape,
				},
				widget = wibox.container.constraint,
				width = left_panel_width,
				strategy = 'max',
			},

			-- Center panel
			{
				{
					{
						widget = task_list(s)
					},
					bg		= beautiful.titlebar_bg_normal,
					widget	= wibox.container.background,
					shape	= tags_shape,
				},
				widget = wibox.container.constraint,
				width = center_panel_width,
				strategy = 'exact',
			},

			-- Right panels (system tray and layout box)
			{
				-- system tray
				{
					{
						system_tray(s),
						bg		= beautiful.titlebar_bg_normal,
						widget	= wibox.container.background,
						shape	= tags_shape,
					},
					widget = wibox.container.constraint,
					width = right_panel_systemtray_width,
					strategy = 'max',
				},
				-- layout box
				{
					layout_box(s),
					bg		= beautiful.titlebar_bg_normal,
					widget	= wibox.container.background,
					shape	= tags_shape,
				},
				spacing = math.floor(screen_width * 0.01),
				layout	= wibox.layout.fixed.horizontal,
			},
			expand	= 'none',
			layout	= wibox.layout.align.horizontal,
		},
		top		= math.floor(screen_height * 0.005),
		left	= math.floor(screen_width * 0.01),
		right	= math.floor(screen_width * 0.01),
		widget	= wibox.container.margin,
	}

end

return upper_panel
