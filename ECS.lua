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

local curService
local addEntities
local rmvEntities
local updated

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

-- cannot produce errors
function ECS.state_set(state, data)
	stateToData[state] = data
end

-- errors if the state DNE or has been freed,
-- including when the component or entity has been freed
function ECS.state_get(component, entity)
	return stateToData[componentToStates[component][entity]]
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
-- waits until the service is done updating to add the entities
function ECS.service_add(service, entity)
	if curService == service then
		updated = true
		addEntities[#addEntities + 1] = entity
	else
		serviceToEntities[service][entity] = true
		entityToServices[entity][service] = true
	end
end

-- errors if the service or entity DNE or have been freed
-- waits until the service is done updating to remove the entities
function ECS.service_rmv(service, entity)
	if curService == service then
		updated = true
		rmvEntities[#addEntities + 1] = entity
	else
		serviceToEntities[service][entity] = nil
		entityToServices[entity][service] = nil
	end
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
-- will cause services with a higher order not to update
-- to avoid this, swap service orders around ans desired
-- before calling this
function ECS.service_free(service)
	local order = serviceToOrder[service]
	orderToService[order] = nil
	serviceToOrder[service] = nil
	serviceToUpdate[service] = nil
	erase(serviceToEntities, service)
end

-- errors if a service's update callback is not a function
-- or if any service's update throws an error
function ECS.update()
	for order, service in ipairs(orderToService) do
		local update = serviceToUpdate[service]

		curService = service
		updated = false

		for entity in next, serviceToEntities[service] do
			update(entity)
		end

		if updated then
			curService = nil

			for i, entity in ipairs(addEntities) do
				ECS.service_add(service, entity)
			end

			for i, entity in ipairs(rmvEntities) do
				ECS.service_rmv(service, entity)
			end
		end
	end
end

return ECS