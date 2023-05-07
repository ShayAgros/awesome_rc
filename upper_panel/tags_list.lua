local awful = require('awful')
local gears = require('gears')
local dpi = require('beautiful').xresources.apply_dpi
local beautiful = require('beautiful')
local wibox = require('wibox')
local client = client


local modkey = "Mod4"
local icon_dir = os.getenv("HOME") .. '/.config/awesome/theme/icons/'

local tags_configurations = {
	{
		icon = icon_dir .. "console.svg",
		colored_icon = icon_dir .. "console_colored.svg",
		type = 'code',
	},
	{
		icon = icon_dir .. "firefox.svg",
		colored_icon = icon_dir .. "firefox_colored.svg",
		type = 'firefox',
	},
	{
		icon = icon_dir .. "google-chrome.svg",
		colored_icon = icon_dir .. "google-chrome_colored.svg",
		type = 'chrome',
	},
	{
		icon = icon_dir .. "slack.svg",
		colored_icon = icon_dir .. "slack_colored.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "folder.svg",
		colored_icon = icon_dir .. "folder_colored.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "console.svg",
		colored_icon = icon_dir .. "console_colored.svg",
		type = 'code',
	},
	{
		icon = icon_dir .. "spotify.svg",
		colored_icon = icon_dir .. "spotify_colored.svg",
		type = 'media',
	},
	{
		icon = icon_dir .. "email.svg",
		colored_icon = icon_dir .. "email_colored.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "key.svg",
		colored_icon = icon_dir .. "key_colored.svg",
		type = 'vpn',
	},
}

local function register_tags(s)
	for i, tag in pairs(tags_configurations) do
		awful.tag.add(
		i,
		{
			icon = tag.icon,
			icon_only = true,
			layout = awful.layout.suit.tile,
			gap_single_client = false,
			--gap = 10,
			screen = s,
			selected = i == 1
		}
		)
	end
end

local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local function paint_when_occupied(object, c, index, _)
  local ib = object:get_children_by_id('tag_icon')[1]
  local tag_configs = tags_configurations[index]

  if index > #tags_configurations then
    print("For some reason called to update tag index", index)
    return
  end

  if #c:clients() > 0 then
    ib:set_image(tag_configs.colored_icon)
  else
    ib:set_image(tag_configs.icon)
  end
end

local rounded_shape = function(cr, width, height)
	gears.shape.rounded_rect(cr, width, height, dpi(8))
end

local tag_widget_template = {
		{
			nil,
			{
				{
					{
						{
							id	 = 'tag_icon',
							widget = wibox.widget.imagebox,
						},
						margins = 2,
						widget  = wibox.container.margin,
					},
					{
						id	 = 'text_role',
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.fixed.horizontal,
				},
				left	 = dpi(2),
				right	= dpi(2),
				top		= dpi(2),
				bottom	= dpi(4),
				widget	= wibox.container.margin
			},
			{
				wibox.widget.base.make_widget(),
				forced_height = dpi(3),
				id	 = 'background_role',
				widget = wibox.container.background,
			},

			--spacing	= -dpi(3),
			layout	= wibox.layout.align.vertical,
		},
		id		= 'focus_role',
		widget	= wibox.container.background,

		-- make the icon colored when it has clients in it
		create_callback = function(self, tag, index, tags)

			self:connect_signal('mouse::enter', function()
				local fb = self:get_children_by_id('focus_role')[1]

				fb:set_bg(beautiful.taglist_mouse_focus)
			end)

			self:connect_signal('mouse::leave', function()
				local fb = self:get_children_by_id('focus_role')[1]

				fb:set_bg(beautiful.titlebar_bg_normal)
			end)

			paint_when_occupied(self, tag, index, tags)
		end,

		update_callback = paint_when_occupied,
}

local create_tags_list = function(s)
	register_tags(s)

	s.taglist = awful.widget.taglist {
        screen  		= s,
        filter  		= awful.widget.taglist.filter.all,
        buttons 		= taglist_buttons,
        style			= {
        	shape = rounded_shape,
        },
		widget_template = tag_widget_template,
		layout			= {
			spacing = 4,
			layout  = wibox.layout.fixed.horizontal,
		}
    }

    return s.taglist
end

return create_tags_list
