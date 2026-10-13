local B = dofile("lib/BuildBudget.lua")
local world, menu = {}, {}
local top
local game = {stack = {top = function() return top end}}
assert(not B.covered(game, world), "Gen2 empty stack must use visible-world budget")
top = world
assert(not B.covered(game, world), "Gen1 world screen must use visible-world budget")
top = menu
assert(B.covered(game, world), "covering menu must use covered budget")
assert(not B.covered(nil, world), "missing game must not imply hidden world")
print("PASS Gen2 empty-stack, Gen1 world-stack and covered-screen build budgets")
