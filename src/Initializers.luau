local q = require("./Types.Quail")
----------------------------------------------------
local Egg = zune.thread
local Nest: q.Nest
local Task = zune.task
----------------------------------------------------
local Initializers = {} :: q.Initializers
----------------------------------------------------
type TypedList<K, V> = q.TypedList<K, V>
type DataPacket = q.DataPacket
type EggPacket<Def> = q.EggPacket<Def>
----------------------------------------------------
function Initializers.Receiver(): ()
	while true do local Thread = coroutine.yield();

		local Received: q.EggPacket<q.CompletedPacket> & q.Field = Thread:receive()
		local List = Nest.EggList[Received.NestID]

		if Received["RequestType"] == "Send" then
			local Callback: (...any) -> () = List.Clutch[Received.Name].Callbacks[Received.ID]

			local ThreadContext = table.find(Initializers.ThreadCache, Thread)

			if Callback then
				Callback(Received.Data, ThreadContext) ; continue
			else
				print(`Orphaned Data on... Module: {Received.Name}, ID: {Received.ID}`)
			end

		elseif Received["RequestType"] == "RequestSync" then
			List.BevyList = Received.Data
		end
	end
end

local Receivers: {thread} = {}
----------------------------------------------------
local function Queue(): ()
	for _,Thread in Initializers.ReceiveQueue do
		Task.spawn(
			Receivers[table.find(Initializers.ThreadCache, Thread) :: number],
			Thread
		)
	end; table.clear(Initializers.ReceiveQueue)
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

	local Coro = coroutine.create(Initializers.Receiver)
	coroutine.resume(Coro) ; table.insert(Receivers, Coro)
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
