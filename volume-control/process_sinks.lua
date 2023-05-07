#!/usr/bin/env lua
local _, spawn = pcall(require, "awful.spawn")

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
local function query_sinks(pavu_lines)
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
        if current_sink.State == "RUNNING" then
          sinks.active = current_sink
        end

        current_sink = nil
        do break end
      end

      local current_sink_nr
      _, _, current_sink_nr = string.find(line, "^Sink #([0-9]+)$")
      if current_sink == nil and current_sink_nr == nil then
        print("Failed to extract sink number from line")
        print(line)
        os.exit(2)
      end

      -- initialize current sink
      if current_sink == nil then
        current_sink = { ["number"] = current_sink_nr, ["indent"] = 0 }
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
    if current_sink.State == "RUNNING" then
      sinks.active = current_sink
    end
    table.insert(sinks, current_sink)
  end

  return sinks
end

function pavu:query_sinks_async(cb_func)
  local sinks
  -- called from command line
  if arg[0] then
    local f = assert(io.open("./sample_sinks.txt", "r"))
    if f then
      sinks = query_sinks(f)
      f:close()
    end

    -- no really asynchronous
    cb_func(sinks)
  else
    spawn.easy_async_with_shell(
      "pactl list sinks",
      function(stdout, _, _, _)
        sinks = query_sinks(stdout)
        cb_func(sinks)
      end)
  end
end

function pavu:test()
  self:query_sinks_async(function(sinks)
    local inspect = require "inspect"
    for i, sink in ipairs(sinks) do
      print("============================== Sink number", i, "==============================")
      print(inspect(sink))
      print("\n\n\n\n\n\n\n\n")
    end
  end
  )
end

if arg[0] then
  pavu:test()
end

return pavu
