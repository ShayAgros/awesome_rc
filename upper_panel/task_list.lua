local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local dpi = require('beautiful').xresources.apply_dpi
local client = client

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local task_list_layout = {
		spacing = 2,
		layout  = wibox.layout.fixed.horizontal
}

local task_list_widget_template = {
	{
		{
			id     = 'icon_role',
			widget = wibox.widget.imagebox,
		},
		margins = dpi(5),
		widget = wibox.container.margin
	},
	{
		wibox.widget.base.make_widget(),
		forced_height = dpi(3),
		id	 = 'background_role',
		widget = wibox.container.background,
		visible = false,
	},
	spacing = -dpi(3),
	layout	= wibox.layout.fixed.vertical,
	update_callback = function(self, c, index, objects) --luacheck: no unused
		local bar = self:get_children_by_id('background_role')[1]
		-- this fixes a bug in which the tasklist item is drawn before an icon
		-- exists
		if c and c.icon then
			bar:set_visible(true)
		end
	end,
}

local function create_task_list(s)
    s.tasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
		layout = task_list_layout,
		buttons  = tasklist_buttons,
		widget_template = task_list_widget_template,
    }

	return s.tasklist
end

return create_task_list
