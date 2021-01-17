-- Puzzle icon

local wibox = require("wibox")
local gears = require("gears")
local cairo = require("lgi").cairo

puzzle_icon = {}

puzzle_icon.widget = wibox.widget
	{
		widget = wibox.widget.imagebox,
		resize = true,
	}

-- create an empty canvas
local surface = cairo.ImageSurface.create(cairo.Format.ARGB32, 382.516, 210.732)

local is = gears.surface("/home/ANT.AMAZON.COM/shayagr/workspace/drawings/ticket.svg")
local image = cairo.ImageSurface.create_from_png("/home/ANT.AMAZON.COM/shayagr/workspace/drawings/puzzle.png")
local cr  = cairo.Context(surface)


-- Scale to images proportion
cr:scale (382.516 / image.width, 210.732 / image.height)
--cr:set_source_surface(image, 0, 0)

cr:set_source_rgb(75, 75, 75)
cr:mask_surface(image, 0, 0)

cr:fill()

--cr:paint()

--cr:set_line_width (0.1);
--cr:set_source_rgb (0, 0, 0);
--cr:rectangle (0, 0, 15, 15);
--cr:stroke()

--cr:set_source_rgb(75, 75, 75)

puzzle_icon.widget:set_image(surface)

puzzle_icon.shape = function (cr, width, height)

	radius = 10
	--cr:set_source_surface(is, 0, 0)

	-- Scale to images proportion
	--cr:scale (width / image.width, height / image.height)
	--cr:rectangle (width/4, height/4, width/2, height/2);
	cr:mask_surface(image, 0, 0)
	--cr:close_path()
	--cr:fill()

	cr:stroke()
	--cr:paint()
	--cr:move_to(0, radius)

	--cr:move_to(height/2, 0)
	--cr:line_to(height, width/2)
	--cr:line_to(height/2, width)
	--cr:line_to(0, width/2)
	--cr:close_path()

end

return puzzle_icon
