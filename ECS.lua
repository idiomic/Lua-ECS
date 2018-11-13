local function erase(relations, key)
	for _, links in next(relations[key]) do
		links[key] = nil
	end
	relations[key] = nil
end

local entityToServices = {}
local entityToStates = {}
local stateToEntity = {}
local stateToComponent = {}
local stateToData = {}
local componentToStates = {}
local componentToInit = {}
local componentToFree = {}
local serviceToEntities = {}
local serviceToUpdate = {}
local serviceToOrder = {}
local orderToService = {}

local ECS = {}

-- cannot produce errors
function ECS.entity_init()
	local entity = #entityToStates + 1
	entityToStates[entity] = {}
	entityToServices[entity] = {}
	return entity
end

-- errors if the entity DNE or is already freed
function ECS.entity_free(entity)
	erase(entityToStates, entity)
	erase(entityToServices, entity)
end

-- errors if the entity or component DNE or have been freed
-- or the component's init callback is not a function
function ECS.state_init(entity, component, ...)
	local state = componentToStates[component][entity]
	if state then
		stateToData[state] = componentToInit[component](...)
		return state
	end

	state = #stateToComponent + 1
	componentToStates[component][entity] = state
	entityToStates[entity][component] = state

	stateToComponent[state] = component
	stateToEntity[state] = entity
	stateToData[state] = componentToInit[component](...)
	return state
end

-- errors if the state DNE or is already freed
-- or the component's free callback is not a function
function ECS.state_free(state)
	local entity = stateToEntity[state]
	local component = stateToComponent[state]
	componentToStates[component][entity] = nil
	entityToStates[entity][component] = nil

	local data = stateToData[state]
	stateToComponent[state] = nil
	stateToEntity[state] = nil
	stateToData[state] = nil
	componentToFree[component](data)
end

-- cannot produce errors
-- can cause state_init and state_free to error if init and free are not callbacks
function ECS.component_init(init, free)
	local component = #componentToInit + 1
	componentToStates[component] = {}
	componentToInit[component] = init
	componentToFree[component] = free
	return component
end

-- errors if the component DNE or is already freed
function ECS.component_free(component)
	componentToInit[component] = nil
	componentToFree[component] = nil
	erase(componentToStates, component)
end

-- cannot produce errors
-- can cause update to error if update isn't a callback
function ECS.service_init(update)
	local service = #serviceToEntities + 1
	serviceToEntities[service] = {}
	serviceToUpdate[service] = update

	local order = #orderToService + 1
	orderToService[order] = service
	serviceToOrder[service] = order
	return service, order
end

-- errors if the service or entity DNE or have been freed
function ECS.service_add(service, entity)
	serviceToEntities[service][entity] = true
	entityToServices[entity][service] = true
end

-- errors if the service or entity DNE or have been freed
function ECS.service_rmv(service, entity)
	serviceToEntities[service][entity] = nil
	entityToServices[entity][service] = nil
end

-- erros if a service DNE or has been freed
function ECS.service_swap(service_1, service_2)
	local order_1 = serviceToOrder[service_1]
	local order_2 = serviceToOrder[service_2]
	serviceToOrder[service_1] = order_2
	orderToService[order_2] = service_1
	serviceToOrder[service_2] = order_1
	orderToService[order_1] = service_2
	return order_1, order_2
end

-- errors if the service or entity DNE or have been freed
function ECS.service_free(service)
	local order = serviceToOrder[service]
	orderToService[order] = nil
	serviceToOrder[service] = nil
	serviceToUpdate[service] = nil
	erase(serviceToEntities, service)
end

-- errors if a service's update callback is not a function
function ECS.update()
	for order, service in ipairs(orderToService) do
		local update = serviceToUpdate[service]
		for entity in next, serviceToEntities[service] do
			update(entity)
		end
	end
end

return ECS