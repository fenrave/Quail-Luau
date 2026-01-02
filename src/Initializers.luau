local q = require("./Types.Quail")
local Case = require("./extModules/case")
----------------------------------------------------
local Egg = zune.thread
local Nest: q.Nest
local Task = zune.task
----------------------------------------------------
local Initializers = {} :: q.Initializers
local InactiveReceivers: {thread} = {}
local ActiveReceivers: {thread} = {}
local ThreadTables = {}
----------------------------------------------------
type TypedList<K, V> = q.TypedList<K, V>
type DataPacket = q.DataPacket
type EggPacket<Def> = q.EggPacket<Def>
----------------------------------------------------
Initializers.CoroutineCase = Case(
	"ReceiverFunctions",
	{
		Send = function(List, Received, ThreadContext)
			local Callback: (...any) -> () = List.Clutch[Received.Name].Callbacks[Received.ID]
			
			if Callback then
				Callback(Received.Data, ThreadContext) ; return
			end

			print(
				`Orphaned Data on... Module: {Received.Name}, ID: {Received.ID}`
			)
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
		suspended = function(Co: thread, Thread: Thread, Index: number)
			Task.spawn(Co,Thread) ; table.remove(Initializers.ReceiveQueue, Index)
		end,
		dead = function(Co: thread, Thread: Thread, Index: number, Position: number)
			local Coro = coroutine.create(Initializers.Receiver)
			coroutine.resume(Coro, #InactiveReceivers, Coro) ; table.insert(InactiveReceivers, Coro)
		end
	}
)

function Initializers.Receiver(SelfIndex: number, thread: thread): ()
	ThreadTables[thread] = {
		Yielding = false
	}
	while true do local Thread = coroutine.yield()
		ThreadTables[thread].Yielding = true
		local Received: q.EggPacket<q.CompletedPacket> & q.Field = Thread:receive()

		Initializers.CoroutineCase[Received.RequestType](
			Nest.EggList[Received.NestID],
			Received,
			table.find(Initializers.ThreadCache, Thread)
		); Task.wait()

		table.insert(InactiveReceivers, thread) ; table.remove(ActiveReceivers, SelfIndex)
		ThreadTables[thread].Yielding = false
	end
end
----------------------------------------------------
local function Queue(): ()
	for Index,Thread in Initializers.ReceiveQueue do
		local Position = table.find(Initializers.ThreadCache, Thread) :: number
		local Co = InactiveReceivers[Position]
		if not Co or ThreadTables[Co].Yielding then
			continue
		end

		table.insert(ActiveReceivers, Co)
		table.remove(InactiveReceivers, Position)

		local Status = coroutine.status(Co)

		Initializers.QueueCase[Status](Co, Thread, Index, Position)
	end
end

-- local function Queue(): ()
-- 	repeat
-- 		local Receiver = InactiveReceivers[1]
-- 		if ThreadTables[Receiver].Yielding then
-- 			table.remove(InactiveReceivers, 1)
-- 			table.insert(ActiveReceivers, Receiver)
-- 			continue
-- 		end
-- 			local NextQueue = Initializers.ReceiveQueue[1]
-- 			if not NextQueue then
-- 				break
-- 			end

-- 			table.remove(InactiveReceivers, 1)
-- 			table.insert(ActiveReceivers, Receiver)

-- 			Initializers.QueueCase[coroutine.status(Receiver)](
-- 				Receiver,
-- 				NextQueue,
-- 				1
-- 			)
		
-- 	until #InactiveReceivers <= 0 or #Initializers.ReceiveQueue <= 0
-- end
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

for i = 1,100 do
	local Coro = coroutine.create(Initializers.Receiver)
	coroutine.resume(Coro, i, Coro) ; table.insert(InactiveReceivers, Coro)
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

function Initializers:Async(Burrow: q.BurrowType, Amount, ID): q.AsyncHandler
	local MetaIndexer = setmetatable({
		Threads = GetThreads(Amount, ID),
		ID = ID,
	}, {
		__newindex = function(List: q.AsyncHandler, Index: string | number, Job: EggPacket<q.Parallel>): ()
			for _, Async in self.AsyncHandlers[List.ID] do
				Async.CurrentJob = Job
			end
		end,
	}) :: q.AsyncHandler

	self.AsyncHandlers[ID] = {}

	local InternalPseudo = table.clone(self.PseudoPacket)

	for i: number = 1, Amount do
		local Handler: q.AsyncThread = setmetatable(
			{
				ID = ID,
			},{
				__newindex = function(List: q.Indexer, Index: string | number, Job: EggPacket<q.Parallel>): ()
					if not Job.Data[i] then
						return
					end

					InternalPseudo.Data = Job.Data[i]
					InternalPseudo.ThreadContext = tonumber(tostring(List.ID .. i))
					InternalPseudo.ID = Job.ID
					InternalPseudo.NestID = Job.NestID
					InternalPseudo.Name = Job.Name

					MetaIndexer.Threads[i]:send(InternalPseudo)

					table.insert(self.ReceiveQueue,MetaIndexer.Threads[i])
						
				end,
			}
		)

		table.insert(self.AsyncHandlers[ID], i, Handler)
	end

	return MetaIndexer
end

local function PassList(List: q.Nest)
	Nest = List
end

return {Initializers = Initializers, PassList = PassList}
