-- Power management widget

local wibox = require("wibox")
local awful = require("awful")
local naughty = require("naughty")
local gears = require("gears")

local function read_file()
	local file = io.open("/sys/class/power_supply/BAT0/capacity", "r")
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function get_charging_string()
	local file = io.open("/sys/class/power_supply/BAT0/status", "r")
    if not file then return "" end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    if content == "Charging\n" then return "C" end
    if content == "Discharging\n" then return "DC" end
    return "F"
end

local power_widget = { mt = {} }

function power_widget:create_widget()
	local widget = wibox.widget.textbox()
	widget.set_align("right")
	widget:set_markup("100")
	return widget
end


function power_widget:update_power()
	local plvl = read_file()
	local c_str = get_charging_string()

	power_widget.widget:set_markup(string.format('% 3d[%s]', plvl, c_str))
	return p_lvl
end


local function show_message()
	naughty.notify{
					text = "Hello there battery",
					title = "Unread Emails",
					timeout = 5, hover_timeout = 0.5,
					width = 400,
	}
end

local function new(...)

	power_widget.widget = power_widget:create_widget()

	awful.tooltip{objects={power_widget.widget},
						   bg="#3c3851",
						   mode="outside",
						   timer_function = function()
								return "Hello battery"
						   end,}

	power_widget.power_lvl = power_widget:update_power()

	power_widget:update_power()

	power_widget.timer = gears.timer({ timeout = 0.5 })
	power_widget.timer:connect_signal("timeout", function() power_widget:update_power() end)
	power_widget.timer:start()

	--power_widget.widget:connect_signal("mouse::enter", function() show_message() end)

	return power_widget.widget
end

function power_widget.mt:__call(...)
    return new(...)
end


return setmetatable(power_widget, power_widget.mt)
