# Lua-ECS

An implementation of the core essentials of every
Entity-Component-System setup in Lua.

# Errors
Each function's possible errors are documented in the source.
Error checks for invalid arguments are not included, but the
functions will quickly error as documented in the comments.
Error checking is omitted for speed and simplicity.

# API
There are four different types in the API:
	entity
	component
	service
	state

Entities define new objects (identity), states are attached
to the entity and are instances of a component, and services
are a callbacks that are called with components they are
connected to and manipulate their state.

The functions exposed start with a type name or 'update'.
After the type, an underscore ('\_') precedes the method
name. All types have methods 'init' and 'free', components have
'get', and services have 'add', 'rmv', and 'swap'. 'get' is
used to get the state associated with the component of an
entity, 'add' and 'rmv' are used to add and remove entities
from the list of entities a service acts on, and 'swap' swaps
the order in which services are executed when 'update' is
called. There are no other functions. (Well, besides the
'reset' function which you should only call in the most dire
of circumstances, like major error recovery)

When any of the four 'init's are called, they return the new
object. These objects are numbers, but are related to each
other as defined in the internal tables of ECS. In the case
if 'service_init', the order the service will be called in
when 'update' is called will also be returned. 'service_swap'
also returns the updated orders.

# Events
A common need is to include some sort of 'event' system. In
an UI accepting user input, input needs to be somehow given
to the services acting on that input. When an event occurs,
it should be immediately put into the ECS system as the state
of an entity. This probably means creating an event service
that runs before every other service and creates new states
on entities listening to external events. It could also
register these entities with an event handler service for the
appropriate event type. Events that are created later in the
update than the handler for that event will be caught the
next time update is called. Handlers can remove the event
component and unregister the entity from themselves. Any
changes to the entities registered to a currently updating
service are queued until the service finishes updating.

An example event system for an IDE would be something like
this: Keyboard and click event creator services run first.
They modify the keyboard and click components on registered
entities. A keyboard handler service runs sometime later
checks if the character is a space, newline, or changes the
text's token type. If it is a space, it creates a new entity
and registers it with the keyboard event creator service.
It does the same for a newline character, but adds the
appropriate components for a new line rather than a new word.
Otherwise if the new word formed is a keyword, it sets the
style component's state appropriately. If semantic analysis
is running, it creates a new semantic change component and
registers the entity with the semantic change handler
service. Later, the semantic change handler grabs that
semantic change component and does its thing, optionally
changing the entity's sytle component. Near the end, the
text renderer takes the text component and style component
and spits it out on the screen.

This implementation of ECS allows for easy ephemoral
components for events and similiar systems, along side more
perminant storage like UI handles. It also allows easy
one time execution like event handlers and repeated
execution like animations. 

# Implementations Principles
ECS was implemented in such a way that calling scripts cannot
obtain or modify internal ECS state, except in defined ways.
methods which modify ECS state return the modifications made,
and it is left up to the calling script to decide how, if at
all, the information about the ECS state is stored. For
example, some callers may create services and setup the order
in which they are called once and not store information about
the services anymore. Because the ECS implementation is
deterministic, values such as states and orders may be hard
coded. Other callers may dynamically control or even add/rmv
services at runtime and need to keep track of service order.

# General ECS principles
All state should be stored in components. Optimally, NOTHING
should exist outside ECS. You know this is being achieved when
the only data services observe and manipulate is contained
inside a component. This allows for easy debugging by
observing components.

While it may be possible to create a few monolithic services,
allowing easy communication between parts of the service, this
is an antipattern. This makes code much less modular. Services
should be broken down as much as possible into atomic
operations. The same goes for components. Smallar, more
predictable components allows higher modularity and
reusability. The great advantage of ECS is its composition:
defining new substances with atom rather than molecule sized
services and components is easier. Another great advantage is
the decoupling that happens when breaking an application into
services that don't care about eachother, only the state
present in the components. But also beware, while micro
services are good, "entity" services are an antipattern:
https://www.ben-morris.com/entity-services-when-microservices-are-worse-than-monoliths/