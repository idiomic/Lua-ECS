local ECS = {}

function ECS:entity_new()
	local new = #self.entities + 1
	self.entities[new] = true
	return new
end

function ECS:entity_add(entity, componentID)
	local component = self.components[componentID]
	component[entity] = component.init(entity)
end

function ECS:entity_remove(entity, componentID)
	self.components[componentID][entity] = nil
end

function ECS:entity_delete(entity)
	self.entities[entity] = nil
end

function ECS:component_new(init)
	local new = #self.components + 1
	self.components[new] = { init = init }
	return new
end

function ECS:component_set(componentID, init)
	self.components[componentID].init = init
end

function ECS:component_delete(componentID)
	self.components[componentID] = nil
end

function ECS:service_new(update)
	local new = #self.aspects + 1
	self.aspects[new] = {}
	self.updates[new] = update
	return new
end

function ECS:service_set(service, update)
	self.updates[service] = update
end

function ECS:service_add(service, componentID)
	local aspect = self.aspects[service]
	aspect[componentID] = true
end

function ECS:service_remove(service, componentID)
	local aspect = self.aspects[service]
	aspect[componentID] = nil
end

function ECS:service_delete(service)
	self.updates[service] = nil
	self.aspects[service] = nil
end

function ECS:update()
	local components = self.components
	local operations = self.operations
	local entities = self.entities
	local updates = self.updates
	local aspects = self.aspects
	for operationID = 1, #operations do
		local service = operations[operationID]
		local update = updates[service]
		local aspect = aspects[service]
		for entity = 1, #entities do
			local args = {}
			for componentID in next, aspect do
				local component = components[componentID][entity]
				if component == nil then
					args = nil
					break
				end
				args[componentID] = component
			end
			if args then
				update(args)
			end
		end
	end
end

ECS.__index = ECS
return function()
	return setmetatable({
		components = {};
		operations = {};
		entities = {};
		updates = {};
		aspects = {};
	}, ECS)
end