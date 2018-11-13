local ECS = require(script.Parent.ECS)

local amt = 100
local w = 0.2

local times = {}

wait(3)

local s = tick()
for i = 1, amt do
	
end
local c = tick() - s

local s = tick()
for i = 1, amt do
	ECS.entity_init()
end
times.entity_init = (tick() - s - c) / amt

wait(w)

local function update() end
s = tick()
for i = 1, amt do
	ECS.service_init(update)
end
times.service_init = (tick() - s - c) / amt

wait(w)

local function init() return {} end
local function free() end
s = tick()
for i = 1, amt do
	ECS.component_init(init, free)
end
times.component_init = (tick() - s - c) / amt

wait(w)

s = tick()
for i = 1, amt do
	ECS.state_init(i, i)
end
times.state_init = (tick() - s - c) / amt

wait(w)

s = tick()
for i = 1, amt do
	ECS.component_get(i, i)
end
times.component_get = (tick() - s - c) / amt

wait(w)

s = tick()
for i = 1, amt do
	ECS.service_add(i, i)
end
times.service_add = (tick() - s - c) / amt

wait(w)

s = tick()
for i = 1, amt do
	ECS.service_rmv(i, i)
end
times.service_rmv = (tick() - s - c) / amt

wait(w)

s = tick()
for i = 1, amt do
	ECS.service_swap(i, amt - i + 1)
end
times.service_swap = (tick() - s - c) / amt

wait(w)

s = tick()
ECS.update()
times.update = tick() - s

wait(w)

-- Only one 'free' method can run in a test for accurate results
--
local s = tick()
for i = 1, amt do
	ECS.entity_free(i)
end
times.entity_free = (tick() - s - c) / amt


--[[
s = tick()
for i = 1, amt do
	ECS.service_free(i)
end
times.service_free = (tick() - s - c) / amt
]]

--[[
s = tick()
for i = 1, amt do
	ECS.component_free(i)
end
times.component_free = (tick() - s - c) / amt
]]

--[[
s = tick()
for i = 1, amt do
	ECS.state_free(i)
end
times.state_free = (tick() - s - c) / amt
]]

wait(w)

for key, value in next, times do
	print(math.floor(1000000000 * value + 0.5), key)
end