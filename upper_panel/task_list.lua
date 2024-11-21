local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require('beautiful').xresources.apply_dpi
local client = client

local tasklist_buttons = gears.table.join(
    awful.button({}, 1, function(c)
        if c == client.focus then
            c.minimized = true
        else
            c:emit_signal(
                "request::activate",
                "tasklist",
                { raise = true }
            )
        end
    end),
    awful.button({}, 3, function()
        awful.menu.client_list({ theme = { width = 250 } })
    end),
    awful.button({}, 4, function()
        awful.client.focus.byidx(1)
    end),
    awful.button({}, 5, function()
        awful.client.focus.byidx(-1)
    end))

local rounded_shape = function(cr, width, height)
    gears.shape.rounded_rect(cr, width, height, dpi(8))
end

local task_list_widget_template = {
    {
        nil,
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
            id            = 'background_role',
            widget        = wibox.container.background,
            visible       = false,
        },
        layout = wibox.layout.align.vertical,
    },
    id              = 'focus_role',
    widget          = wibox.container.background,

    create_callback = function(self, c, index, objects) --luacheck: no unused
        local bar = self:get_children_by_id('background_role')[1]

        self:connect_signal('mouse::enter', function()
            local fb = self:get_children_by_id('focus_role')[1]

            fb:set_bg(beautiful.tasklist_mouse_focus)
        end)

        self:connect_signal('mouse::leave', function()
            local fb = self:get_children_by_id('focus_role')[1]

            fb:set_bg(beautiful.titlebar_bg_normal)
        end)

        -- this fixes a bug in which the tasklist item is drawn before an icon
        -- exists
        if c and c.icon then
            bar:set_visible(true)
        end
    end,

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
        screen          = s,
        filter          = awful.widget.tasklist.filter.currenttags,
        layout          = {
            spacing = 2,
            layout  = wibox.layout.fixed.horizontal
        },
        buttons         = tasklist_buttons,
        style           = {
            shape = rounded_shape,
        },
        widget_template = task_list_widget_template,
    }

    return s.tasklist
end

local function make_state_icon_widget(image)
    local icon_image = wibox.widget {
            widget = wibox.widget.imagebox,
            image = image,
            resize = true,
            visible = true,
    }

    local icon_container = wibox.widget.base.make_widget_declarative {
        icon_image,
        margins = dpi(8),
        widget = wibox.container.margin,
        icon = icon_image,
    }

    return icon_container
end

local function create_state_icons(s)
    local filesystem = require("gears.filesystem")
    local config_dir = filesystem.get_configuration_dir()
    local icon_dir = config_dir .. "/upper_panel/icons"
    local floating_icon = icon_dir .. "/plane.png"

    s.si_visible = make_state_icon_widget(floating_icon)

    local stateicons = wibox.widget.base.make_widget_declarative {
        layout          = wibox.layout.fixed.horizontal,
        s.si_visible,
    }

    return stateicons
end

local function create_task_layout(s)
    create_task_list(s)

    local stateicons = create_state_icons(s)

    local task_layout = wibox.widget.base.make_widget_declarative {
        layout = wibox.layout.align.horizontal,
        s.tasklist,
        nil,
        stateicons
    }

    local update_state_flags = function(c)
        if c.screen ~= s then
            return
        end

        s.si_visible.icon.visible = c.floating
    end

    client.connect_signal("focus", update_state_flags)
    client.connect_signal("request::geometry", update_state_flags)
    client.connect_signal("property::floating", update_state_flags)

    return task_layout
end

return create_task_layout
