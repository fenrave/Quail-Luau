--!strict
local q = require("./Types.Quail")
----------------------------------------------------
local Egg = zune.thread
local Task = zune.task
local RGEN = zune.random.new()
local Nest = {} :: q.Nest
----------------------------------------------------
export type ModuleSetupDef = q.ModuleSetupDef
export type EggDef<Def> = q.EggDef<Def>
export type Dict = q.Dict
----------------------------------------------------
local InternalList: q.EggList = {}
Nest.EggList = setmetatable({}, {
		__index = InternalList,
		__newindex = InternalList
	}
)

local RequestEnum: {string} = {
	[1] = "Module",
	[2] = "Send",
	[3] = "Sync",
	[4] = "RequestSync"
}

----------------------------------------------------
local QuailHandle = {} :: q.QuailHandle

function QuailHandle:Remove()
	self.Handle.State = 2
	self = nil :: any
end

function QuailHandle:Disable()
	self.Handle.State = 1
end

function QuailHandle:Enable()
	self.Handle.State = 0
end

----------------------------------------------------
Nest.RoutineList = {}
Nest.Timer = 1/240
Nest.NoInternalSchedule = false
----------------------------------------------------
function Nest:ToggleScheduler()
	Nest.NoInternalSchedule = not Nest.NoInternalSchedule --Inverts state
end

function Nest:Scheduler(): ()
	while not Nest.NoInternalSchedule do
		for _, Routine in self.RoutineList do
			Routine()
		end; Task.wait(self.Timer)
	end
end
Task.spawn(Nest.Scheduler, Nest)
----------------------------------------------------
function Nest:NewNest(EggAmount: number)
	local NewList = {
		Egg = nil :: any,
		Nest = {},
		Clutch = {},
		BevyList = {},
		CurrentEgg = 1
	} :: q.BurrowType

	for i: number = 1, EggAmount or 5 do
		local NewEgg: Thread = Egg.fromModule("./Burrow")

		table.insert(
			NewList.Nest,
			NewEgg
		); NewEgg:start()

	end; NewList.Egg = NewList.Nest[1]

	local BevyUpdate: q.EggPacket<typeof(NewList.BevyList)> = {
		Data = NewList.BevyList,
		ID = RGEN:nextInteger(0, 9999999999999),
		Name = "Sync",
		RequestAmount = 0,
		RequestType = RequestEnum[3]
	}

	local BevyRequest: q.EggPacket<nil> = {
		ID = RGEN:nextInteger(0, 9999999999999),
		Name = "Request",
		RequestAmount = 0,
		RequestType = RequestEnum[4]
	}

	local function InternalScheduler(): ()
		local JobCount: number = 0
		local Egg: Thread = NewList:NextEgg()
		
		BevyUpdate.Data = NewList.BevyList
		Egg:send(BevyUpdate)
		
		for _, Module in NewList.Clutch do
			for Index, Job in Module.Jobs do
				if Job.State == 2 or Job.RequestAmount == 0 then
					Module.Jobs[Index] = nil
					continue
				elseif Job.State == 1 then
					continue
				end
				
				Job.ThreadContext = NewList.CurrentEgg
				Job.RequestAmount = if Job.RequestAmount > 0 then
										Job.RequestAmount - 1 
									else 
										-1
					
				JobCount += 1 ; Egg:send(Job)
			end
		end

		local Received: q.EggPacket<q.CompletedPacket>
		local Callback: (...any) -> ()

		if JobCount > 0 then
			repeat JobCount -= 1;

				--yields on receive
				Received = Egg:receive()
			
				Callback = NewList.Clutch[Received.Name].Callbacks[Received.ID]

				if Callback then
					Callback(Received.Data) ; continue
				else
					print(`Orphaned Data on... Module: {Received.Name}, ID: {Received.ID}`)
				end
			until JobCount <= 0
		end

		Egg:send(BevyRequest)
		
		NewList.BevyList = Egg:receive()
	end; table.insert(self.RoutineList, InternalScheduler)

	function NewList:InitBevy(Name: string)
		if not self.BevyList[Name] then
			self.BevyList[Name] = {}
		end

		return self.BevyList[Name]
	end

	function NewList:NextEgg(): Thread
		local NextIndex: number = self.CurrentEgg + 1
		local NextEgg: Thread = self.Nest[NextIndex]
		
		if not NextEgg then
			NextEgg = self.Nest[1]
			NextIndex = 1
		end; self.CurrentEgg = NextIndex

		self.Egg = NextEgg ; return NextEgg
	end

	function NewList:OnComplete(ModuleName: string, ID: number, fn: (...any) -> ()): ()
		self.Clutch[ModuleName].Callbacks[ID] = fn
	end

	function NewList:AssignJob<M>(EggDef: q.EggDef<M>): q.QuailHandle
		
		local NewPacket: q.EggPacket<M> = {
			Name = EggDef.ModuleName,
			ID = RGEN:nextInteger(0,9999999999999),
			RequestType = if type(EggDef.Type) ~= "string" then
					RequestEnum[EggDef.Type]
				else
					EggDef.Type,
			RequestAmount = EggDef.Limit or -1,
			Data = EggDef.Data,
			State = 0,
			ThreadContext = 0
		}

		NewList.Clutch[EggDef.ModuleName].Jobs[NewPacket.ID] = NewPacket

		local NewHandle = table.clone(QuailHandle) ; NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[#InternalList] = NewList

	return NewList
end

function Nest:AddModule(pEgg: ModuleSetupDef): ()

	local CurrentNest = pEgg.Nest
	for i, Egg in CurrentNest.Nest do
		for Name, ModulePath in pEgg.Modules do

			local NewPacket: q.EggPacket<q.ModulePacket> = {
				Name = Name,
				ID = RGEN:nextInteger(0,9999999999999),
				RequestType = RequestEnum[1],
				RequestAmount = 0 :: number,
				Data = {
					Path = ModulePath
				},
				State = 0
			}

			CurrentNest.Clutch[Name] = {
				Jobs = {},
				Callbacks = {}
			}
			
			Egg:send(NewPacket)
		end
		
	end
	
	-- for _, Egg in CurrentNest.Nest do
	-- 	Egg:receive()
	-- end

end

function Nest:RemoveModule()
end



return Nest