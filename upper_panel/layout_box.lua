local wibox = require("wibox")
local awful = require('awful')
local gears = require('gears')
local dpi = require('beautiful').xresources.apply_dpi

for _, l in ipairs(awful.layout.layouts) do
	awful.layout.remove_default_layout(l)
end

awful.layout.append_default_layouts(awful.layout.suit.tile)
awful.layout.append_default_layouts(awful.layout.suit.floating)

local function create_layout_box(s)
    local layout_box = awful.widget.layoutbox(s)

    layout_box:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))

	s.layoutbox = wibox.widget.base.make_widget_declarative {
		layout_box,
		margins = dpi(8),
		widget = wibox.container.margin,
	}

	return s.layoutbox
end

return create_layout_box
