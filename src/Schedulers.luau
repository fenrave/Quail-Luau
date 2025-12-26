--!strict
local q = require("./Types.Quail")
----------------------------------------------------
local RGEN: Random = zune.random.new()
local Task = zune.task
----------------------------------------------------
local SchedulerList = {} :: q.SchedulerList
----------------------------------------------------
type JobCache = {[q.BurrowType]: {[Thread]: number}}
----------------------------------------------------
local function Receiver(Egg: Thread, NewList: q.BurrowType): ()
	local Received: q.EggPacket<q.CompletedPacket> = Egg:receive()

	local Callback: (...any) -> () = NewList.Clutch[Received.Name].Callbacks[Received.ID]

	if Callback then
		Callback(Received.Data) ; return
	else
		print(`Orphaned Data on... Module: {Received.Name}, ID: {Received.ID}`)
	end
end
----------------------------------------------------
local ParallelJobCache: JobCache = {}
local QueueJobCache: JobCache = {}
----------------------------------------------------
function SchedulerList:Queue(NewList: q.BurrowType, BevyUpdate, BevyRequest): ()
	local Egg: Thread = NewList:NextEgg()
	local CurrentEgg = NewList.CurrentEgg

	if not QueueJobCache[NewList] then
		QueueJobCache[NewList] = {}
	end; local JobCount = QueueJobCache[NewList]
	
	BevyUpdate.Data = NewList.BevyList ; Egg:send(BevyUpdate)

	JobCount[Egg] = 0
	for _, Module in NewList.Clutch do
		for Index, Job in Module.Jobs do
			if Job.State == 2 or Job.RequestAmount == 0 then
				Module.Jobs[Index] = nil
				continue
			elseif Job.State == 1 then
				continue
			end; Job.ThreadContext = CurrentEgg

			Job.RequestAmount = if Job.RequestAmount >= 0 then Job.RequestAmount - 1 else -1

			JobCount[Egg] += 1 ; Egg:send(Job)
		end
	end

	if JobCount[Egg] > 0 then
		repeat JobCount[Egg] -= 1;
			Receiver(Egg, NewList)
		until JobCount[Egg] <= 0
	end

	Egg:send(BevyRequest) ; NewList.BevyList = Egg:receive()
end

function SchedulerList:Parallel(NewList: q.BurrowType, BevyUpdate, BevyRequest): ()
	if not ParallelJobCache[NewList] then
		ParallelJobCache[NewList] = {}
	end; local JobCount = ParallelJobCache[NewList]

	local SubCache: {q.EggPacket<any>} = {}

	for Current,Egg in NewList.Nest do
		JobCount[Egg] = 0
		for _, Module in NewList.Clutch do
			for Index, Job in Module.Jobs do
				if Job.State == 2 then
					Module.Jobs[Index] = nil
					continue
				elseif Job.State == 1 then
					continue
				end

				if not table.find(SubCache, Job) then
					table.insert(SubCache, Job)
				end; Job.ThreadContext = Current
				
				JobCount[Egg] += 1 ; Task.spawn(Egg.send, Egg, Job)
			end
		end
	end

	for _, Egg in NewList.Nest do
		repeat JobCount[Egg] -= 1;
			Receiver(Egg, NewList)
		until JobCount[Egg] <= 0
	end

	for _,Job in SubCache do
		if Job.RequestAmount == 0 then
			Job.State = 2 ; continue
		end

		Job.RequestAmount = if Job.RequestAmount > 0 then Job.RequestAmount - 1 else -1
	end

end


return SchedulerList