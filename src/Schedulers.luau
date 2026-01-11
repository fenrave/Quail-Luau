--!strict
local q = require("./Types.Quail")
local Init = require("./Initializers").Initializers
----------------------------------------------------
local Task = zune.task
----------------------------------------------------
local SchedulerList = {} :: q.SchedulerList
----------------------------------------------------
function SchedulerList:Queue(NewList: q.BurrowType, NestID: number): ()
	local Thread: Thread = NewList:NextThread()
	local CheckedList: q.TypedList<number, boolean> = {}
	local TID = tonumber(tostring(NestID..NewList.CurrentThread))
	NewList.BevyUpdate.ThreadContext = TID

	for _, Module in NewList.Clutch do
		for Index, Job in Module.Jobs do
			if Job.State == 2 or Job.RequestAmount == 0 then
				Module.Jobs[Index] = nil
				continue
			elseif Job.State == 1 then
				continue
			end; Job.ThreadContext = TID
			Job.NestID = NestID

			if not CheckedList[Job.ID] then
				Job.RequestAmount = if Job.RequestAmount >= 0 then Job.RequestAmount - 1 else -1
			end

			Thread:send(Job) ; table.insert(Init.ReceiveQueue, Thread)
		end
	end
end

function SchedulerList:Parallel(NewList: q.BurrowType, NestID: number): ()
	local CheckedList: q.TypedList<number, boolean> = {}
	local SubCache: q.TypedList<number, q.ThreadPacket<q.Parallel>> = {}

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

return SchedulerList