local nameToAssembly
local entityToServices
local entityToStates
local stateToEntity
local stateToComponent
local stateToData
local nameToComponent
local componentToStates
local componentToInit
local componentToFree
local nameToService
local serviceToEntities
local serviceToUpdate
local serviceToOrder
local orderToService
local serviceToMessages

local ECS = {}

function ECS.assembly_init(name, assembly)
	nameToAssembly[name] = assembly
end

function ECS.assembly_free(name)
	nameToAssembly[name] = nil
end

-- cannot produce errors
function ECS.entity_init()
	local entity = #entityToStates + 1
	entityToStates[entity] = {}
	entityToServices[entity] = {}
	return entity
end

-- errors if the entity DNE or is already freed
function ECS.entity_free(entity)
	local free = ECS.free
	for component, state in next, entityToStates[entity] do
		componentToStates[component][state] = nil
		
		local free = componentToFree[component]
		if free then
			free(stateToData[state])
		end

		stateToComponent[state] = nil
		stateToEntity[state] = nil
		stateToData[state] = nil
	end
	entityToStates[entity] = nil

	local rmv = ECS.rmv
	for service in next, entityToServices[entity] do
		serviceToEntities[service][entity] = nil
	end
	entityToServices[entity] = nil
end

-- errors if the entity DNE or has been freed
function ECS.init(entity, name, ...)
	local component = nameToComponent[name]
	if not component then
		local assembly = nameToAssembly[name]
		if assembly then
			assembly(entity, ...)
		else
			warn 'Attempt to call init with a non-existant component/assembly'
		end
		return
	end
	
	local state = componentToStates[component][entity]
	if not state then
		state = #stateToComponent + 1
		componentToStates[component][entity] = state
		entityToStates[entity][component] = state
	
		stateToComponent[state] = component
		stateToEntity[state] = entity
	end

	stateToData[state] = componentToInit[component](entity, ...) or ...
	return state
end

-- errors if the component DNE or has been freed
function ECS.get(entity, name)
	return stateToData[componentToStates[nameToComponent[name]][entity]]
end

-- errors if the state DNE or is already freed
-- or the component DNE or its free callback is not a function
function ECS.free(entity, name)
	local state = componentToStates[nameToComponent[name]][entity]

	local entity = stateToEntity[state]
	local component = stateToComponent[state]
	componentToStates[component][entity] = nil
	entityToStates[entity][component] = nil
	
	local free = componentToFree[component]
	if free then
		free(stateToData[state])
	end
	
	stateToComponent[state] = nil
	stateToEntity[state] = nil
	stateToData[state] = nil
end

-- cannot produce errors
-- can cause state_init and state_free to error if init and free are not callbacks
function ECS.component_init(name, init, free)
	local component = #componentToInit + 1
	componentToStates[component] = {}
	componentToInit[component] = init
	componentToFree[component] = free
	nameToComponent[name] = component
	return component
end

-- errors if the component DNE or is already freed
function ECS.component_free(name)
	local component = nameToComponent[name]
	nameToComponent[name] = nil

	componentToInit[component] = nil
	componentToFree[component] = nil

	local free = ECS.state_free
	for entity, state in next, componentToStates[component] do
		free(state)
	end
	componentToStates[component] = nil
end

-- cannot produce errors
-- can cause update to error if update isn't a callback
function ECS.service_init(name, update)
	local service = #serviceToEntities + 1
	serviceToEntities[service] = {}
	serviceToUpdate[service] = update
	nameToService[name] = service

	local order = #orderToService + 1
	orderToService[order] = service
	serviceToOrder[service] = order
	return service, order
end

-- errors if the service or entity DNE or have been freed
-- waits until the service is done updating to add the entities
function ECS.add(entity, name)
	local service = nameToService[name]
	serviceToEntities[service][entity] = true
	entityToServices[entity][service] = true
end

-- errors if the service or entity DNE or have been freed
-- waits until the service is done updating to remove the entities
function ECS.rmv(entity, name)
	local service = nameToService[name]
	serviceToEntities[service][entity] = nil
	entityToServices[entity][service] = nil
end

-- erros if a service DNE or has been freed
function ECS.service_swap(name_1, name_2)
	local service_1 = nameToService[name_1]
	local service_2 = nameToService[name_2]
	local order_1 = serviceToOrder[service_1]
	local order_2 = serviceToOrder[service_2]
	serviceToOrder[service_1] = order_2
	orderToService[order_2] = service_1
	serviceToOrder[service_2] = order_1
	orderToService[order_1] = service_2
	return order_1, order_2
end

-- errors if the service or entity DNE or have been freed
-- will cause services with a higher order not to update
-- to avoid this, swap service orders around as desired
-- before calling this
function ECS.service_free(name)
	local service = nameToService[name]
	nameToService[name] = nil

	local order = serviceToOrder[service]
	orderToService[order] = nil
	serviceToOrder[service] = nil
	serviceToUpdate[service] = nil

	for entity in next, serviceToEntities[service] do	
		serviceToEntities[service][entity] = nil
		entityToServices[entity][service] = nil
	end
end

-- errors if a service's update callback is not a function
-- or if any service's update throws an error
function ECS.update()
	for order, service in ipairs(orderToService) do
		serviceToUpdate[service](serviceToEntities[service])
	end
end

-- the big red button your mom told you to never push
-- cannot error, cannot be undone.
function ECS.reset()
	nameToAssembly = {}
	entityToServices = {}
	entityToStates = {}
	stateToEntity = {}
	stateToComponent = {}
	stateToData = {}
	nameToComponent = {}
	componentToStates = {}
	componentToInit = {}
	componentToFree = {}
	nameToService = {}
	serviceToEntities = {}
	serviceToUpdate = {}
	serviceToOrder = {}
	orderToService = {}
end

ECS.reset()

local interface = newproxy(true)
local metatable = getmetatable(interface)
metatable.__metatable = 'This metatable is locked'
metatable.__index = ECS
local newindexMsg = 'Attempt to set [%s] to (%s) on a locked table'
function metatable:__newindex(key, value)
	return error(newindexMsg:format(tostring(key), tostring(value)))
end

return ECS