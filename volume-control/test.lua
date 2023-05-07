#!/usr/bin/env lua

local str = "                balance -0.39"

local _, _, value = string.find(str, "^%s+([^%s].+)$")

print(value)
