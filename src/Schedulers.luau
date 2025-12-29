--!strict
local q = require("./Types.Quail")
----------------------------------------------------
local Task = zune.task
----------------------------------------------------
local SchedulerList = {} :: q.SchedulerList
----------------------------------------------------
type JobCache = {[q.BurrowType]: {[Thread]: number}}
----------------------------------------------------
local PseudoPacket: q.EggPacket<q.Parallel> = {
	Name = "Temp",
	ID = 1,
	RequestType = "Send",
	RequestAmount = -1,
	Data = {},
	State = 0,
	ThreadContext = 0
}
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
function SchedulerList:Queue(NewList: q.BurrowType, BevyUpdate, BevyRequest, NestID: number): ()
	local Egg: Thread = NewList:NextEgg()
	local CurrentEgg: number = NewList.CurrentEgg
	local CheckedList: q.TypedList<number, boolean> = {}

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
			end; Job.ThreadContext = tonumber(tostring(NestID..CurrentEgg))

			if not CheckedList[Job.ID] then
				Job.RequestAmount = if Job.RequestAmount >= 0 then Job.RequestAmount - 1 else -1
			end; CheckedList[Job.ID] = true
			
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

function SchedulerList:Parallel(NewList: q.BurrowType, BevyUpdate, BevyRequest, NestID: number): ()
	if not ParallelJobCache[NewList] then
		ParallelJobCache[NewList] = {}
	end; local JobCount = ParallelJobCache[NewList]

	local CheckedList: q.TypedList<number, boolean> = {}
	local SubCache: {q.EggPacket<q.Parallel>} = {}

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

				--This check is to prevent running the job without data assigned to the thread
				if not Job.Data[Current] then
					continue
				end

				if not table.find(SubCache, Job) then
					table.insert(SubCache, Job)
				end; Job.ThreadContext = tonumber(tostring(NestID..Current))

				PseudoPacket.Data = Job.Data[Current]
				PseudoPacket.ThreadContext = Current
				PseudoPacket.ID = Job.ID
				PseudoPacket.Name = Job.Name
				
				JobCount[Egg] += 1 ; Task.spawn(Egg.send, Egg, PseudoPacket)
			end
		end
	end

	for _, Egg in NewList.Nest do
		if JobCount[Egg] > 0 then
			repeat JobCount[Egg] -= 1;
				Receiver(Egg, NewList)
			until JobCount[Egg] <= 0
		end
	end

	for _,Job in SubCache do
		if Job.RequestAmount == 0 then
			Job.State = 2 ; continue
		end

		if not CheckedList[Job.ID] then
			Job.RequestAmount = if Job.RequestAmount > 0 then Job.RequestAmount - 1 else -1
		else
			continue
		end; CheckedList[Job.ID] = true
	end

end


return SchedulerList