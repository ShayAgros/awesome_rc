-------------------------------------------------
-- Reviews Widget for Awesome Window Manager
--
-- Currently only using gerrit
--
-- @author Shay Agroskin
--
-- Inspired by Pavel Makhov version of gerrit, but was written from scratch
-------------------------------------------------

local button = require("awful.button")
local util = require("awful.util")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local naughty = require("naughty")
local gears = require("gears")
local beautiful = require("beautiful")
local mouse = mouse

local dpi = require('beautiful').xresources.apply_dpi

local mpopup = require("gerrit-widget.mpopup")
local json = require("gerrit-widget.json")

local HOME_DIR = os.getenv("HOME")

local GET_PASS_CMD = "gpg -q --for-your-eyes-only --no-tty -d ~/.emacs.d/.mbsyncpass.gpg | sed -n '6p'"

-- surround url with quotes so that the shell won't interpret it
--local GET_CHANGES_CMD = [[curl -s -X GET -u shayagr:%s '%s/a/changes/?q=%s']]
local GET_CHANGES_CMD = [[ ssh -p 29418 %s gerrit query --format=JSON %s 2>/dev/null | sed '1s/^/[/ ; $s/$/]/; $q ; s/$/,/' ]]

------------------------------------------
-- gerrit backend functions
------------------------------------------

local gerrit_backend_obj = { mt = {} }

function gerrit_backend_obj:init(args)

	args = args or {}

	--self.host	= args.host	or 'https://gerrit.anpa.corp.amazon.com:9080'
	self.host	= args.host	or 'gerrit.anpa.corp.amazon.com'
	self.query	= args.query or 'is:reviewer AND status:open AND NOT is:wip AND NOT reviewedby:self AND NOT owner:self'

	self.reviews = {}
	self.previous_reviews = {}

	return self
end

function gerrit_backend_obj:query_password()
		spawn.easy_async_with_shell(GET_PASS_CMD, function(stdout)
			stdout = stdout:gsub("\n", "")
			self.pass = stdout

			naughty.notify {
				icon = HOME_DIR ..'/.config/awesome/gerrit-widget/gerrit_icon.svg',
				title = 'pass',
				text = "Querying",
			}
		end)
end

function gerrit_backend_obj:query_command()
	--if self.pass == nil then
		--self:query_password()
	--end
	--print_output(string.format(GET_CHANGES_CMD, self.pass, self.host, self.query:gsub(" ", "+")))
	--return string.format(GET_CHANGES_CMD, self.pass, self.host, self.query:gsub(" ", "+"))
	return string.format(GET_CHANGES_CMD, self.host, self.query)
	--return "cat /home/ANT.AMAZON.COM/shayagr/reviews.json | sed '1s/^/[/ ; $s/$/]/; $q ; s/$/,/'"
end

function gerrit_backend_obj:process_command_output(output)
	local reviews = {}
	local new_reviews = {}

	-- first line in the curl output is trash, remove it
	--output = output:gsub("^[^\n]*\n", "")
	if output == "" then
		return reviews, new_reviews
	end

	--print_output(output)
	--print("Called to process query output")
	local json_reviews = json.decode(output)

	for _, review in ipairs(json_reviews) do
	--for review_str in string.gmatch(s,'[^\r\n]+') do
		--local review = json.decode(review_str)

		-- One entry cotains stats metadata. TODO: decide whether to use it (or
		-- specify that you want all reviews all the time)
		if review.subject then
			--print("processing review w subject", review.subject)
			local review_entry = {
				subject = review.subject,
				author	= review.owner.name,
				project	= review.project,
				website	= 'https://' .. self.host .. ':9080/' .. review.number,
				number  = review.number,
			}
			table.insert(reviews, review_entry)

			-- Check if review is new or if it has been updated
			if not self.previous_reviews["r" .. review.number] then
				table.insert(new_reviews, review_entry)
			end

			-- Add when the last review was updated
			reviews["r" .. review.number] = true
		end
	end

	--print("queried", reviews, "patches")

	self.previous_reviews = reviews

	return reviews, new_reviews
end

function gerrit_backend_obj.mt:__call(self, ...)
    return gerrit_backend_obj:init(...)
end

gerrit_backend_obj = setmetatable(gerrit_backend_obj, gerrit_backend_obj.mt)

------------------------------------------
-- gerrit backend functions
------------------------------------------

local reviews_widget = {}

function reviews_widget:add_review_site(site_backend, site_icon_path, site_icon_new_path)
	-- icon picture when there aren't new reviews
	local site_icon			= gears.surface(site_icon_path)
	-- icon picture when there are new reviews (optional)
	local site_icon_new		= site_icon_new_path and gears.surface(site_icon_new_path) or site_icon
	-- number of code reviews (in wibar)
	local wibar_nr_review	= wibox.widget.textbox("nc")
	-- code review site icon
	local wibar_icon		= wibox.widget.imagebox(site_icon)

	-- pop up menu to list the reviews
	local menu = mpopup {
		ontop = true,
		visible = false,
		shape = gears.shape.rounded_rect,
		border_width = 1,
		border_color = beautiful.bg_focus,
		maximum_height = 600,
		offset = { y = 5 },
		widget = {}
	}

	local site = {
		-- meta data
		backend			= site_backend,
		site_icon		= site_icon,
		site_icon_new	= site_icon_new,
		new_reviews		= false,

		-- widgets
		menu			= menu,
		wibar_icon		= wibar_icon,
		wibar_nr_review	= wibar_nr_review,
	}

	table.insert(self.review_sites, site)
end

function reviews_widget:create_wibar_widget()

	local site_widgets = {}
	local wibar_widget

	local add_backend = function(backend_site)
		local site_widget = wibox.widget {
			-- review icon
			{
				backend_site.wibar_icon,
				id		= "image_container",
				margins	= 4,
				layout	= wibox.container.margin
			},
			-- number of reviews
			backend_site.wibar_nr_review,
			layout	= wibox.layout.fixed.horizontal,
			site	= backend_site,

			set_new_icon = function(self)
				local new_icon		= self.site.site_icon_new
				local wibar_icon	= self.site.wibar_icon

				wibar_icon:set_image(new_icon)
			end,

			set_regular_icon = function(self)
				local site_icon		= self.site.site_icon
				local wibar_icon	= self.site.wibar_icon

				wibar_icon:set_image(site_icon)
			end
		}

		-- show popup menu upon pressing
		site_widget:buttons(
			util.table.join(
				button({}, 1, function()
					local popup_menu = backend_site.menu

					--if popup_menu.widget ~= {} then
						--return
					--end

					if popup_menu.visible then
						popup_menu.visible = not popup_menu.visible
						site_widget:set_regular_icon()
					else
						--popup_menu.visible = true
						popup_menu:move_next_to(mouse.current_widget_geometry)
						site_widget:set_new_icon()
					end
				end)
			)
		)

		return site_widget
	end -- add_backend

	for _, site in ipairs(self.review_sites) do
		local site_widget = add_backend(site)
		table.insert(site_widgets, site_widget)
		site.site_widget = site_widget
	end

	-- Make the widgets horizontal
	site_widgets.layout = wibox.layout.fixed.horizontal

	wibar_widget = wibox.widget(site_widgets)

	self.wibar_widget = wibar_widget
end

-- Create one entry in the popup menu for a review website.
-- Each line has thee vertical fields: project name, patch subject
-- and patch author.
local function create_review_popup_row(review, site_widget, popup_menu)
	local row = wibox.widget
	{
		{
			{
				{
					markup = '<b>' .. review.project .. '</b>',
					align = 'center',
					widget = wibox.widget.textbox
				},
				{
					-- Don't print more than 50 chars
					text = '  ' .. review.subject:sub(1, 50),
					widget = wibox.widget.textbox
				},
				{
					text = '  ' .. review.author,
					widget = wibox.widget.textbox
				},
				vertical_spacing = 10,
				layout = wibox.layout.align.vertical
			},
			left = dpi(10),
			bottom = dpi(5),
			top = dpi(5),
			right = dpi(10),
			layout = wibox.container.margin
		},
		widget = wibox.container.background
	}

	row:connect_signal("mouse::enter", function(b) b:set_bg(beautiful.bg_focus) end)
	row:connect_signal("mouse::leave", function(b) b:set_bg(beautiful.bg_normal) end)

	row:set_bg(beautiful.bg_normal)

	row:buttons(
		util.table.join(
			-- left mouse click
			button({}, 1, function()
				print("xdg-open " .. review.website)
				spawn.with_shell("xdg-open " .. review.website)
				popup_menu.visible = false
				site_widget.site_widget:set_regular_icon()
			end)
		)
	)

	return row
end

-- This function recieves the review table of a review site (i.e.
-- the output of backend_engine.process_command_output()) and updates
-- the pop-up menu of this site.
function reviews_widget:site_update_reviews(site, reviews_table, new_reviews_table)
	local site_menu				= site.menu
	local reviews_num			= #reviews_table
	local new_review_list		= "\n"

	if not reviews_num then
		return
	end

	--print_output(string.format("Queried %d reviews last time", reviews_num))
	--print(string.format("Queried %d reviews last time", reviews_num))

	-- BUG: This doesn't accommodate for less code reviews
	-- don't update widget if there aren't new reviews
	--if #new_reviews_table == 0 then
		--if site.wibar_nr_review.markup ~= "nc" then
		--end
		--return
	--end

	local review_buttons = {
		layout = wibox.layout.fixed.vertical,
	}

	for _, review in ipairs(reviews_table) do
		table.insert(review_buttons, create_review_popup_row(review, site, site_menu))
	end

	site_menu:setup(review_buttons)

	-- send notifications about new reviews. Don't do it if just returned from
	-- disconnection
	if #new_reviews_table ~= 0 and site.wibar_nr_review.markup ~= "nc" then

		for _, review in ipairs(new_reviews_table) do
			new_review_list = new_review_list .. review.author .. ": " .. review.subject .. "\n\n"
		end

		naughty.notify {
			icon = HOME_DIR ..'/.config/awesome/gerrit-widget/gerrit_icon.svg',
			title = 'New Incoming Review',
			text = new_review_list,
		}
	end

	site.wibar_nr_review.markup = string.format("%d", reviews_num)
end

-- For every review site (e.g. gerrit, Github, Amazon code) the function
-- calls its shell query command and then acts upon the commands processed
-- output to update its popup menu of reviews
function reviews_widget:update_reviews()
	for _, site in ipairs(self.review_sites) do
		local backend = site.backend
		spawn.easy_async_with_shell(backend:query_command(),
			function(stdout, stderr, exitreason, exitcode)
				--print("queried and returned with exit code:", exitcode)
				if exitcode == 6 then
					site.wibar_nr_review.markup = "nc"
				elseif exitcode == 0 then
					-- transform the reviews into a table and update site widget
					self:site_update_reviews(site, backend:process_command_output(stdout))
				else
					--naughty.notify {
						--icon = HOME_DIR ..'/.config/awesome/gerrit-widget/gerrit_icon.svg',
						--title = 'failed to query jenkins',
						--text = "",
					--}
				end
			end
		)
	end
end

function reviews_widget:init(args)

	local args = args or {}

	self.review_sites = {}

	-- declare and add backends
	local gerrit_backend = gerrit_backend_obj()
	local gerrit_icon = HOME_DIR .. '/.config/awesome/gerrit-widget/gerrit_icon.svg'
	local gerrit_icon_new_reviews = HOME_DIR .. '/.config/awesome/gerrit-widget/gerrit_icon_busy.svg'

	self:add_review_site(gerrit_backend, gerrit_icon, gerrit_icon_new_reviews)

	-- no create the wibar icon (comes after adding back ends so that we would know
	-- all the icons in it
	self:create_wibar_widget()

	-- start a timer to update all reviews every some intervals
	self.timer = gears.timer {
		timeout		= 30,
		call_now 	= true,
		autostart	= true,
		callback	= function()
			self:update_reviews()
		end
	}

	return self.wibar_widget
end

return setmetatable(reviews_widget, { __call = reviews_widget.init })
