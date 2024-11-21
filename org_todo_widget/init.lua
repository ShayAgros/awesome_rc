local wibox = require ("wibox")
local gears = require("gears")
local spawn = require("awful.spawn")
local filesystem = require("gears.filesystem")
local timer = gears.timer or timer
local dpi = require('beautiful').xresources.apply_dpi

local query_script="~/workspace/scripts/list_todos.sh"
local todo_widget = {}

function todo_widget:fetch_todos()
   spawn.easy_async_with_shell(query_script, function (stdout, _, _, _)
    self.todo_nr:set_markup(stdout)
    end)
end

function todo_widget:new()
  local config_dir = filesystem.get_configuration_dir()
  local module_dir = config_dir .. "/org_todo_widget"
	local widget_img_path = module_dir .. "/book2.png"

	local book_icon = wibox.widget {
		widget = wibox.widget.imagebox,
    image = widget_img_path,
		resize = true,
	}
  self.todo_nr = wibox.widget.textbox()

  self.widget = wibox.widget.textbox()
	self.widget = wibox.widget.base.make_widget_declarative {
		book_icon,
		self.todo_nr,
		spacing = dpi(4),
		layout = wibox.layout.fixed.horizontal,
	}

  self:fetch_todos()
  self.timer = timer({ timeout = 10 })
  self.timer:connect_signal("timeout", function() self:fetch_todos() end)
  self.timer:start()

  return self.widget
end

return setmetatable(todo_widget, {__call = todo_widget.new })
