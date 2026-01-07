local q = require("./Types.Quail")
local Case = require("./extModules/case")
----------------------------------------------------
local Egg = zune.thread
local Nest: q.Nest
local Task = zune.task
----------------------------------------------------
local Initializers = {} :: q.Initializers
local Receivers: {thread} = {}
local ThreadTables = {}
----------------------------------------------------
type TypedList<K, V> = q.TypedList<K, V>
type DataPacket = q.DataPacket
type EggPacket<Def> = q.EggPacket<Def>
----------------------------------------------------
Initializers.CoroutineCase = Case(
	"ReceiverFunctions",
	{
		Send = function(List: q.BurrowType, Received: EggPacket<any>, ThreadContext)
			for _, Callback in List.Clutch[Received.Name].Callbacks[Received.ID] do
				Callback(Received.Data, ThreadContext)
			end
		end,
		RequestSync = function(List, Received)
			List.BevyList = Received.Data
		end,
		Default = function(...)
			print(select(..., 2))
		end
	}
)

Initializers.QueueCase = Case(
	"QueueCase",
	{
		suspended = function(Co: thread, Thread: Thread)
			Task.spawn(Co,Thread)
		end,

		dead = function(Co: thread, Thread: Thread)
			local Coro = coroutine.create(Initializers.Receiver) ; table.remove(Receivers, 1)
			Task.spawn(Coro, 1, Coro) ; table.insert(Receivers, Coro)
		end
	}
)

function Initializers.Receiver(SelfIndex: number, thread: thread, Thread: Thread): ()
	ThreadTables[thread] = {
		Yielding = false
	}
	while true do --local Thread = coroutine.yield()
		ThreadTables[thread].Yielding = true
		local Received: q.EggPacket<q.CompletedPacket> & q.Field = Thread:receive()

		Initializers.CoroutineCase(
			Received.RequestType,
			Nest.EggList[Received.NestID],
			Received
		)

		ThreadTables[thread].Yielding = false
	end
end
----------------------------------------------------
local function Queue(): ()
	for Index, Thread in Initializers.ReceiveQueue do
		local Co = Receivers[1]
		if ThreadTables[Co].Yielding then
			continue
		end
		
		local Status = coroutine.status(Co)

		Initializers.QueueCase[Status](Co, Thread)
	end
end
----------------------------------------------------
Initializers.PseudoPacket = {
	Name = "Temp",
	ID = 1,
	NestID = 0,
	RequestType = "Send",
	RequestAmount = -1,
	Data = {},
	State = 0,
	ThreadContext = 0,
}
----------------------------------------------------
Initializers.ThreadCache = {}
Initializers.AsyncHandlers = {}
Initializers.ReceiveQueue = {}
Initializers.Queue = Queue
----------------------------------------------------
for i = 1, Egg.getCpuCount() do
	local NewEgg = Egg.fromModule("./Burrow") ; NewEgg:start()
	table.insert(Initializers.ThreadCache, NewEgg)
end

for i = 1, #Initializers.ThreadCache do
	local Coro = coroutine.create(Initializers.Receiver)
	coroutine.resume(Coro, i, Coro, Initializers.ThreadCache[i]) ; table.insert(Receivers, Coro)
end

local function GetThreads(Count: number, ID: number): TypedList<number, Thread>
	local ThreadTable: TypedList<number, Thread> = table.clone(Initializers.ThreadCache)

	for _: number = 1, #Initializers.ThreadCache - Count do
		table.remove(ThreadTable, math.random(1, #ThreadTable))
	end; return ThreadTable
end
----------------------------------------------------
function Initializers:Default(Burrow: q.BurrowType, Amount: number, ID): TypedList<number, Thread>
	return GetThreads(Amount, ID)
end

local function PassList(List: q.Nest)
	Nest = List
end

return {Initializers = Initializers, PassList = PassList}
