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

--- Function to create the upper panel in a given screen
---@param s table
local upper_panel = function(s)

	local screen_width = s.geometry.width
	--local screen_height = s.geometry.height

	-- math.floor function is very important here. Passing fractions for widget
	-- width would cause pixels not being displayed correctly
	local left_panel_width = math.floor(screen_width * 0.3)
	local center_panel_width = math.floor(screen_width * 0.3)

	local panel = awful.wibar {
		position	= "top",
		screen		= s,
		height		= dpi(48, s),
		bg			= '#00000000'
		--bg			= '#556B2F'
	}

	--print("xrandr output for screen index", s.index)
	--if s.outputs then
		--local screen_name

		--for key, value in pairs(s.outputs) do
			--screen_name = key
			--print(key, ":", value)
		--end

		--naughty.notify {
			--title = 'Identified screen',
			--text = s.index .. ":" .. screen_name,
			--timeout = 5,
		--}
	--else
		--print("doesn't exist")
	--end

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
					system_tray(s),
					bg		= beautiful.titlebar_bg_normal,
					widget	= wibox.container.background,
					shape	= tags_shape,
				},
				-- layout box
				{
					layout_box(s),
					bg		= beautiful.titlebar_bg_normal,
					widget	= wibox.container.background,
					shape	= tags_shape,
				},
				spacing = dpi(10),
				layout	= wibox.layout.fixed.horizontal,
			},
			expand	= 'none',
			layout	= wibox.layout.align.horizontal,
		},
		--top		= math.floor(screen_height * 0.005),
		top		= dpi(8),
		left	= math.floor(screen_width * 0.01),
		right	= math.floor(screen_width * 0.01),
		bottom  = dpi(8),
		widget	= wibox.container.margin,
	}

end

return upper_panel
