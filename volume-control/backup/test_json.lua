local json = require("json")
local inspect = require("inspect")

local str = '{"index":938467,"event":"new","on":"client"}{"index":938467,"event":"change","on":"client"}{"index":938467,"event":"remove","on":"client"}'

local decoded = json.decode(str)
print(inspect(decoded))
