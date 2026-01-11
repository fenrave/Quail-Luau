local q = require("./Types.Quail")
local Case = require("./extModules/case")
----------------------------------------------------
local Egg = zune.thread
local Nest: q.Quail
local Task = zune.task
----------------------------------------------------
local Initializers = {} :: q.Initializers
local Receivers: TypedList<number, thread> = {}
local ThreadTables = {}
----------------------------------------------------
type TypedList<K, V> = q.TypedList<K, V>
type DataPacket = q.DataPacket
type ThreadPacket<Def> = q.ThreadPacket<Def>
----------------------------------------------------
Initializers.CoroutineCase = Case(
	"ReceiverFunctions",
	{
		SEND = function(List: q.BurrowType, Received: ThreadPacket<any>, ThreadContext)
			for _, Callback in List.Clutch[Received.Name].Callbacks[Received.ID] do
				Callback(Received.Data, ThreadContext)
			end
		end,
		REQUESTSYNC = function(List, Received)
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
		suspended = function(Co: thread)
			Task.spawn(Co)
		end,
		Default = function()
			return
		end
	}
)

function Initializers.Receiver(SelfIndex: number, thread: thread, Thread: Thread): ()
	ThreadTables[thread] = {
		Yielding = false
	}
	while true do coroutine.yield()
		repeat
			ThreadTables[thread].Yielding = true
			local Received: q.ThreadPacket<q.CompletedPacket> = Thread:receive()
			
			table.remove(Initializers.ReceiveQueue[SelfIndex])

			Initializers.CoroutineCase(
				Received.RequestType,
				Nest.NestList[Received.NestID],
				Received,
				SelfIndex
			)
			ThreadTables[thread].Yielding = false
		until #Initializers.ReceiveQueue == 0
	end
end
----------------------------------------------------
local function Queue(): ()
	for _,Receiver in Receivers do
		if ThreadTables[Receiver].Yielding then
			continue
		end
		Initializers.QueueCase(coroutine.status(Receiver), Receiver)
	end
end
----------------------------------------------------
Initializers.PseudoPacket = {
	Name = "Temp",
	ID = 1,
	NestID = 0,
	RequestType = "SEND",
	RequestAmount = -1,
	Data = {},
	State = 0,
	ThreadContext = 0,
}
----------------------------------------------------
Initializers.ThreadCache = {}
Initializers.Queue = Queue
----------------------------------------------------
local function SetupThreads(Number: number)
	Initializers.ReceiveQueue = table.create(Number or 32, table.clone({}))
	for i = 1, Number or 32 do
		local NewEgg = Egg.fromModule("./Burrow") ; NewEgg:start()
		table.insert(Initializers.ThreadCache, NewEgg)
	end

	for i = 1, #Initializers.ThreadCache do
		local Coro = coroutine.create(Initializers.Receiver)
		coroutine.resume(Coro, i, Coro, Initializers.ThreadCache[i]) ; table.insert(Receivers, Coro)
	end
end; Initializers.Setup = SetupThreads

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

local function PassList(List: q.Quail)
	Nest = List
end

return {Initializers = Initializers, PassList = PassList}
