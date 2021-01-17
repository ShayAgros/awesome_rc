local wibox = require('wibox')
local awful = require('awful')
local gears = require('gears')
local dpi = require('beautiful').xresources.apply_dpi
local gerrit = require("gerrit-widget.gerrit")
local volume_ctl = require("volume-control")
local pm = require("battery-control")

local mykeyboardlayout = awful.widget.keyboardlayout()
local mytextclock = wibox.widget.textclock()
local volume_widget = volume_ctl {
	tooltip=true,
	device="pulse", -- device and id not really needed
	--cardid=0		-- but better safe than sorry
}

local function dashed_separator_widget(args)
	args = args or {}

	local intervals = args.intervals or 3
	local attached_widget = args.attached_widget

    local widget = wibox.widget.base.make_widget(nil, nil, {
        enable_properties = true,
    })

	local fit = function(self, context, width, height) -- luacheck: no unused
		local rwidth = math.min(0.3, width)

		-- don't draw separator if attached widget doesn't want to be drawn
		if attached_widget then
			local w, h = wibox.widget.base.fit_widget(self, context, attached_widget, width, height)
			if w == 0 or h == 0 then
				return 0, 0
			end
		end

		return rwidth, height
	end

	local draw = function(self, context, cr, width, height) -- luacheck: no unused

		if width == 0 or height == 0 then
			return
		end

		cr:set_source(gears.color("#ffffff"))

		local piece_height = math.floor(height / intervals)

		for i =1, intervals, 2 do
			local start_height = math.floor(piece_height * (i-1))

			cr:rectangle(0, start_height, width, piece_height)
			end

		-- make sure we fill in all area
		if (piece_height * intervals) ~= height then
			piece_height = height - (piece_height * intervals)

			cr:rectangle(width/2 - 1/2, (piece_height * intervals), 1, piece_height)
		end

		cr:fill()
	end

	rawset(widget, "fit", fit)
	rawset(widget, "draw", draw)

	return widget
end

local padded_shape = function(w, spacing)
	return {
		w,
		draw_empty	= false,
		margins		= spacing,
		widget		= wibox.container.margin,
	}
end

local function create_system_tray(s)
	local systray = wibox.widget.systray()
	local spacing = dpi(6)

	local gerrit_widget = {
		gerrit {host = 'https://gerrit.anpa.corp.amazon.com:9080'},
		margins = dpi(1),
		widget = wibox.container.margin,
	}

	local volume = {
		volume_widget.widget,
		left = 2,
		right = 2,
		top = 2,
		bottom = 6,
		widget = wibox.container.margin,
	}

	s.systemtray = wibox.widget.base.make_widget_declarative {
		-- widgets
		padded_shape(gerrit_widget, spacing),
		dashed_separator_widget { intervals = 10 },

		padded_shape(pm, spacing),
		dashed_separator_widget { intervals = 10 },

		padded_shape(volume, spacing),
		dashed_separator_widget { intervals = 10 },

		padded_shape(mykeyboardlayout, spacing),
		dashed_separator_widget { intervals = 10 },

		padded_shape(systray, spacing),
		dashed_separator_widget { intervals = 10, attached_widget = systray },

		padded_shape(mytextclock, spacing),

		-- layout
		layout = wibox.layout.fixed.horizontal,
	}
	return s.systemtray
end

return create_system_tray
