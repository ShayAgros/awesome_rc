#!/usr/bin/env lua
local _, spawn = pcall(require, "awful.spawn")

-- Lua promises
-- https://github.com/zserge/lua-promises
local deferred = require('deferred')

local function create_entry(line, current_indent, parent)
  local entry

  local _, _, prop, value = string.find(line, '^%s+([^:"]+):%s*(.*)')
  if prop then
    -- "prop: value" or "prop:" (case 2.1.1.1)
    entry = { ["parent"] = parent, ["indent"] = current_indent }
    if value ~= "" then
      table.insert(entry, value)
    end

    parent[prop] = entry
  else
    -- "case" (case 2.1.1.2)
    _, _, value = string.find(line, "^%s+([^%s].+)$")
    if not value then
      print(debug.getinfo(1).currentline, "Encountered unexpected value. Line:")
      print(line)
      os.exit(2)
    end

    entry = value
  end

  return entry
end

-- extract the volume values from the text provided by pavu
local function transform_volume_text(sink)

  local volume = sink.Volume[1]

  local _, i, left = string.find(volume, "([0-9]+)%%")
  local _, _, right = string.find(volume, "([0-9]+)%%", i)

  sink.Volume = {
    left = left,
    right = right
  }

  sink.Volume.muted = sink.Mute[1] == "yes"
end

local pavu = {}

-- algorithm:
--
-- for every line in input
--  if empty line then add current_sink to sinks and set current_sink = nil
--  else if current_sink == nil and line is not of form Sink #N, abort
--  else if current_sink != nil
--    if line == Sink #N, set current_sink = {number = N, indent = 0}
--    else
--      1. set current_indent to current indentation
--      2. check relation with current_sink[indent] and current_indent
--        2.1. if current_sink[indent] < current_indent
--          2.1.1 extract prop, value from the line Prop: Value
--            2.1.1.1 if Found then
--              entry = { [1]: value or nil}
--              entry[parent] = current_sink
--              entry[indent] = current_indent
--              current_sink[prop] = entry
--              current_sink = entry
--            2.1.1.2 else (continuation of values of current prob)
--              entry.insert(line)
--          2.1.2 if current_sink[indent] == current_indent
--            same as 2.1.1.1 (a property which shares a parent with previous
--            one) so extract prop, value from the line Prop: Value and set
--            entry = { [1]: value }
--            entry[parent] = current_sink[parent]
--            entry[indent] = current_indent
--            current_sink[parent][prop] = entry
--            current_sink = entry
--          2.1.3 if current_sink[indent] > current_indent
--            current_sink = current_sink[parent][parent]
--            and then same as 2.1.1
-- TODO: You have to change the way you create entries.
-- It makes no sense that to get the description you'd need to do
--  sinks.Description[1] (it's not expected to get a table back)
local function process_pactl_sinks_output(pavu_lines)
  local current_sink
  local sinks = {}

  for line in pavu_lines:lines() do
    repeat -- strange hack to have "continue" statement in lua
      if #line == 0 then
        while current_sink.parent do
          current_sink = current_sink.parent
        end

        transform_volume_text(current_sink)
        table.insert(sinks, current_sink)

        -- create an easy access to the active sink
        if current_sink.State[1] == "RUNNING" then
          sinks.active = current_sink
        end

        current_sink = nil
        do break end
      end

      local _, _, current_sink_nr = string.find(line, "^Sink #([0-9]+)$")
      if current_sink == nil and current_sink_nr == nil then
        print("Failed to extract sink number from line")
        print(line)
        os.exit(2)
      end

      -- initialize current sink
      if current_sink == nil then
        current_sink = { ["number"] = tonumber(current_sink_nr), ["indent"] = 0 }
        do break end
      end

      local _, _, current_indent = string.find(line, "^(%s+)")
      current_indent = string.len(current_indent)

      if current_sink.indent < current_indent then
        -- case 2.1.1
        local entry = create_entry(line, current_indent, current_sink)
        if type(entry) == "table" then
          current_sink = entry
        else
          -- string
          table.insert(current_sink, entry)
        end
      elseif current_sink.indent == current_indent then
        -- case 2.1.2
        local entry = create_entry(line, current_indent, current_sink["parent"])
        current_sink = entry
      else
        -- case 2.1.3
        current_sink = current_sink["parent"]["parent"]
        local entry = create_entry(line, current_indent, current_sink)
        if type(entry) == "table" then
          current_sink = entry
        else
          -- string
          table.insert(current_sink, entry)
        end
      end

      do break end
    until true
  end

  if current_sink then
    while current_sink.parent do
      current_sink = current_sink.parent
    end
    transform_volume_text(current_sink)

    -- create an easy access to the active sink
    if current_sink.State[1] == "RUNNING" then
      sinks.active = current_sink
    end
    table.insert(sinks, current_sink)
  end

  return sinks
end

function pavu:query_sinks_async()
  local d = deferred.new()
  local sinks
  -- called from command line
  if arg then
    -- In this case we're synchronous
    local command = assert(io.popen("pactl list sinks"))
    if command then
      sinks = process_pactl_sinks_output(command)
      command:close()
    end

    d:resolve(sinks)
  else
    local output_lines = {}
    -- the query_sinks file expects a file. Make the string appear to have lines
    -- function
    output_lines.lines = function(t)
      local i = 0
      local n = #t
      return function()
        i = i + 1
        if i <= n then return t[i] end
      end
    end

    spawn.with_line_callback("pactl list sinks",
      {
        stdout = function(line) table.insert(output_lines, line) end,
        output_done = function()
          sinks = process_pactl_sinks_output(output_lines)
          --print("Active volume is", sinks.active.Volume.left, "muted:", sinks.active.Volume.muted)
          d:resolve(sinks)
          --cb_func(sinks)
        end
      })
  end

  return d
end

function pavu:query_default_sink_async(cb_func)
  self:query_sinks_async():next(function(sinks)
    return self:query_default_sink(sinks)
  end):next(function(default_sink)
    cb_func(default_sink)
  end)
end

-- Modify the volume, amount is in percentage and can be negative
function pavu:modify_volume(sink, amount)
  local sink_name = sink.Name[1]

  local new_volume
  local current_vol
  if amount >= 0 then
    current_vol = math.max(sink.Volume.left, sink.Volume.right)
    print(current_vol + amount)
    new_volume = math.min(current_vol + amount, 100)
  else
    current_vol = math.min(sink.Volume.left, sink.Volume.right)
    print(current_vol + amount)
    new_volume = math.max(current_vol + amount, 0)
  end

  -- remove decimal point which pactl doesn't know how to read
  new_volume = math.floor(new_volume)

  sink.Volume.left = new_volume
  sink.Volume.right = new_volume
  --print("modifying volume to", new_volume)

  if arg then
    --print("Executing", "pactl set-sink-volume " .. sink_name .. " " .. new_volume .. "%")
    os.execute("pactl set-sink-volume " .. sink_name .. " " .. new_volume .. "%")
  else
    --print("Executing", "pactl set-sink-volume " .. sink_name .. " " .. new_volume .. "%")
    spawn("pactl set-sink-volume " .. sink_name .. " " .. new_volume .. "%")
  end
end

function pavu:toggle_mute()
  if arg then
    os.execute("pactl set-sink-mute @DEFAULT_SINK@ toggle")
  else
    spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle")
  end
end

-- Asynchronous, uses promises
-- Gets the query result of the default sink
---@param sinks table
function pavu:query_default_sink(sinks)
  local d = deferred.new()

  local function default_sink_by_name(_sinks, default_sink_name)
    for _, sink in ipairs(_sinks) do
      local sink_name = sink.Name[1]

      if default_sink_name == sink_name then
        return sink
      end
    end
  end

  if arg then
    local command = assert(io.popen("pactl get-default-sink"))

    local default_sink_str = command:read("*line")
    command:close()

    d:resolve(default_sink_by_name(sinks, default_sink_str))
  else

    local output_lines = {}
    spawn.with_line_callback("pactl get-default-sink",
      {
        stdout = function(line) table.insert(output_lines, line) end,
        output_done = function()
          local default_sink_str = output_lines[1]
          d:resolve(default_sink_by_name(sinks, default_sink_str))
        end
      })
  end

  return d
end

function pavu:set_event_listener(callback_function)
  print("Setting event listener")
  local pid = spawn.with_line_callback("pactl subscribe", {
    stdout = function(line)

      print("Received a line:", line)
      local _, _, entity = string.find(line, "Event '%a+' on (%a+)")

      if entity ~= "sink" then
        do return end
      end

      callback_function()

    end,
    stderr = function(line)
      print("got error", line)
    end
  })

  -- If the rc is a number then the process has been executed
  -- successfully
  if type(pid) == "number" then
    awesome.connect_signal("exit", function()
      spawn.spawn({"kill", tostring(pid)})
    end)
  end
end

function pavu:set_default_sink(sink_index)
  if arg then
    os.execute("pactl set-default-sink " .. tostring(sink_index))
  else
    spawn("pactl set-default-sink " .. tostring(sink_index))
  end
end

function pavu:test_query()
  self:query_sinks_async():next(function(sinks)
    local inspect = require "inspect"
    for i, sink in ipairs(sinks) do
      print("============================== Sink number", i, "==============================")
      print(inspect(sink))
      print("\n\n\n\n\n\n\n\n")
    end

    print("============================== Active sync ==============================")
    print(inspect(sinks.active))
    print("\n\n\n\n\n\n\n\n")
  end
  )
end

function pavu:test_volume_change()
  self:query_sinks_async():next(function(sinks)
    print("Executing volume change")
    self:modify_volume(sinks.active, 30)
  end)
end

function pavu:test_list_sinks()
  print("List of sinks:")

  --local sink_names = self:list_sinks()
  --for _, sink_name in ipairs(sink_names) do
    --print(sink_name)
  --end
end

function pavu:test_get_default_index()
  self:query_sinks_async()
    :next(function (sinks)
      print("Received", #sinks, "responses")
      return self:query_default_sink(sinks)
  end):next(function(default_sink)
      print("index is", default_sink.number)
  end)
end

function pavu:test_query_default_sink()
  self:query_default_sink_async(function(sink)
    print("Default sink is", sink.Description[1])
  end)
end

-- are we executed directly ? (not from another lua script)
if arg then
  pavu:test_get_default_index()
  --pavu:test_query()
  --pavu:test_list_sinks()
  --pavu:test_volume_change()
end

return pavu
