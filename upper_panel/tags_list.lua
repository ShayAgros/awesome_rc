local awful = require('awful')
local gears = require('gears')
local dpi = require('beautiful').xresources.apply_dpi
local wibox = require('wibox')
local client = client


local modkey = "Mod4"
local icon_dir = os.getenv("HOME") .. '/.config/awesome/upper_panel/icons/'

local tags_configurations = {
	{
		icon = icon_dir .. "console.svg",
		type = 'code',
	},
	{
		icon = icon_dir .. "firefox.svg",
		type = 'firefox',
	},
	{
		icon = icon_dir .. "google-chrome.svg",
		type = 'chrome',
	},
	{
		icon = icon_dir .. "slack.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "folder.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "console.svg",
		type = 'code',
	},
	{
		icon = icon_dir .. "spotify.svg",
		type = 'media',
	},
	{
		icon = icon_dir .. "email.svg",
		type = 'social',
	},
	{
		icon = icon_dir .. "key.svg",
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
			gap_single_client = true,
			gap = 4,
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

local tag_widget_template = {
		{
			{
				{
					{
						id     = 'icon_role',
						widget = wibox.widget.imagebox,
					},
					margins = 2,
					widget  = wibox.container.margin,
				},
				{
					id     = 'text_role',
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.fixed.horizontal,
			},
			left 	= dpi(2),
			right	= dpi(2),
			top		= dpi(2),
			bottom	= dpi(6),
			widget	= wibox.container.margin
		},
		{
			wibox.widget.base.make_widget(),
            forced_height = 1,
			id	 = 'background_role',
			widget = wibox.container.background,
		},
		spacing = -dpi(2),
		layout	= wibox.layout.fixed.vertical,
}

local create_tags_list = function(s)
	register_tags(s)

	s.taglist = awful.widget.taglist {
        screen  		= s,
        filter  		= awful.widget.taglist.filter.all,
        buttons 		= taglist_buttons,
		widget_template = tag_widget_template,
		layout			= {
			spacing = 4,
			layout  = wibox.layout.fixed.horizontal,
		}
    }

    return s.taglist
end

return create_tags_list
