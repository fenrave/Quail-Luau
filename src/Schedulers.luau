--!strict
local q = require("./Types.Quail")
local Init = require("./Initializers").Initializers
----------------------------------------------------
local Task = zune.task
----------------------------------------------------
local SchedulerList = {} :: q.SchedulerList
----------------------------------------------------
function SchedulerList:Queue(NewList: q.BurrowType, NestID: number): ()
	local Egg: Thread = NewList:NextEgg()
	local CurrentEgg: number = NewList.CurrentEgg
	local CheckedList: q.TypedList<number, boolean> = {}

	NewList.BevyUpdate.Data = NewList.BevyList ; Egg:send(NewList.BevyUpdate)

	for _, Module in NewList.Clutch do
		for Index, Job in Module.Jobs do
			if Job.State == 2 or Job.RequestAmount == 0 then
				Module.Jobs[Index] = nil
				continue
			elseif Job.State == 1 then
				continue
			end; Job.ThreadContext = tonumber(tostring(NestID..CurrentEgg))
			Job.NestID = NestID

			if not CheckedList[Job.ID] then
				Job.RequestAmount = if Job.RequestAmount >= 0 then Job.RequestAmount - 1 else -1
			end; CheckedList[Job.ID] = true
			
			Egg:send(Job)

			table.insert(Init.ReceiveQueue, Egg)
		end
	end

	Egg:send(NewList.BevyRequest)

	table.insert(Init.ReceiveQueue, Egg)
end

function SchedulerList:Parallel(NewList: q.BurrowType, NestID: number): ()
	local CheckedList: q.TypedList<number, boolean> = {}
	local SubCache: q.TypedList<number, q.EggPacket<q.Parallel>> = {}

	for Current, Egg: Thread in NewList.Nest do
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

				Init.PseudoPacket.Data = Job.Data[Current]
				Init.PseudoPacket.ThreadContext = Job.ThreadContext
				Init.PseudoPacket.ID = Job.ID
				Init.PseudoPacket.NestID = NestID
				Init.PseudoPacket.Name = Job.Name
				
				Egg:send(Init.PseudoPacket)
				table.insert(Init.ReceiveQueue, Egg)
			end
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

function SchedulerList:Async(NewList: q.BurrowType, NestID: number): ()
	local Indexer: q.AsyncHandler = NewList.Nest
	local CheckedList: q.TypedList<number, boolean> = {}
	local SubCache: q.TypedList<number, q.EggPacket<q.Parallel>> = {}

	for _, Module in NewList.Clutch do
		for Index, Job in Module.Jobs do
			if not table.find(SubCache, Job) then
				table.insert(SubCache, Job)
			end

			Indexer.CurrentJob = Job :: q.EggPacket<q.Parallel>
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