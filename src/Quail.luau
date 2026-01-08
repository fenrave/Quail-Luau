--!strict
local q = require("./Types.Quail")
local Schedulers = require("./Schedulers")
local InitModule = require("./Initializers")
local Initializers = InitModule.Initializers
local Passer = InitModule.PassList 
----------------------------------------------------
local Egg = zune.thread
local Task = zune.task
local RGEN: Random = zune.random.new()
local Nest = {} :: q.Nest ; Passer(Nest)
----------------------------------------------------
export type ModuleSetupDef = q.ModuleSetupDef
export type EggDef<Def> = q.EggDef<Def>
export type Dict = q.Dict
----------------------------------------------------
--[==[
@Queue Data in the `Data` Field is sent to each Thread sequentially & in an ordered manner.

```luau
local Data: Queue = {
	Hi = "hello!" --Each thread will be passed this data.
}
```
You can sequentially mutate this data so each thread gets a new version on a Job Callback.

]==]--
export type Queue = q.Queue
----------------------------------------------------
--[==[
@Parallel Data in the `Data` Field is distributed over each Thread. You assign which data goes to which
Thread gets what data based on its array position.

```luau
local Data: Parallel = {
	[1] = {}, --Thread 1
	[2] = {}  --Thread 2
	--etc
}
```
You can mutate this data between Parallel cycles, as opposed to @Queue, which per Thread.
]==]--
export type Parallel = q.Parallel
----------------------------------------------------
type TypedList<K, V> = q.TypedList<K, V>
type DataPacket = q.DataPacket
type EggPacket<Def> = q.EggPacket<Def>
----------------------------------------------------
local NumberCache: TypedList<number, number> = {}
----------------------------------------------------
local function GenID(): number
	local Number = RGEN:nextInteger(100000, 999999)

	if table.find(NumberCache, Number) then
		return GenID()
	end; table.insert(NumberCache, Number)

	return Number
end
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
local InternalList: q.EggList = {}
Nest.EggList = setmetatable({}, {
		__index = InternalList,
		__newindex = InternalList
	}
)

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

		if #Initializers.ReceiveQueue > 0 then
			Initializers.Queue()
		end

	end
end; Task.spawn(Nest.Scheduler, Nest)
----------------------------------------------------
function Nest:NewNest(EggAmount: number, SchedType: string?)
	if SchedType == nil then
		SchedType = "Queue"
	end; assert(SchedType ~= nil)

	EggAmount = math.clamp(EggAmount, 1, #Initializers.ThreadCache)

	local NewList = {
		Egg = nil :: any,
		Nest = {} :: any,
		Clutch = {},
		BevyList = {},
		CurrentEgg = 1,
		NestID = GenID(),
		SchedType = SchedType
	} :: q.BurrowType
	
	NewList.InternalScheduler = Schedulers[SchedType]

	NewList.Nest = Initializers["Default"](Initializers, NewList, EggAmount, NewList.NestID)
	NewList.Egg = NewList.Nest[1]

	NewList.BevyUpdate = {
		Data = NewList.BevyList,
		NestID = NewList.NestID,
		ID = GenID(),
		Name = "Sync",
		RequestAmount = 0,
		RequestType = q.RequestEnum[3]
	}

	NewList.BevyRequest = {
		NestID = NewList.NestID,
		ID = GenID(),
		Name = "Request",
		RequestAmount = 0,
		RequestType = q.RequestEnum[4]
	}

	local function Internal(): ()
		NewList.InternalScheduler(Schedulers, NewList, NewList.NestID)
	end; table.insert(self.RoutineList, Internal)

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

	function NewList:OnComplete(Handle, fn: <Type>(...Type) -> ()): ()
		local List = self.Clutch[Handle.Name].Callbacks

		if not List[Handle.ID] then
			List[Handle.ID] = {}
		end

		List[Handle.ID][GenID()] = fn
	end

	function NewList:AssignJob(EggDef: q.EggDef<DataPacket>): q.QuailHandle
		local NewPacket: q.EggPacket<DataPacket> = {
			Name = EggDef.ModuleName,
			ID = GenID(),
			NestID = NewList.NestID,
			RequestType = if type(EggDef.Type) ~= "string" then
					q.RequestEnum[EggDef.Type]
				else
					EggDef.Type,
			RequestAmount = EggDef.Limit or -1,
			Data = EggDef.Data,
			State = 0,
			ThreadContext = 0
		}

		if not NewList.Clutch[EggDef.ModuleName] then
			error("Module wasn't loaded, or failed to load before assignment.")
		end

		NewList.Clutch[EggDef.ModuleName].Jobs[NewPacket.ID] = NewPacket :: EggPacket<any>

		local NewHandle = table.clone(QuailHandle) ; NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[NewList.NestID] = NewList

	return NewList
end

function Nest:AddModule(pEgg: ModuleSetupDef): ()
	local CurrentNest = pEgg.Nest
	local Nest = CurrentNest.Nest

	for i, Egg in Nest do
		for Name, ModulePath in pEgg.Modules do

			local NewPacket: q.EggPacket<q.ModulePacket> = {
				Name = Name,
				ID = GenID(),
				NestID = CurrentNest.NestID,
				RequestType = q.RequestEnum[1],
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

end

function Nest:RemoveModule(pEgg: ModuleSetupDef)
	local CurrentNest = pEgg.Nest

	for i, Egg in CurrentNest.Nest do
		for Name in pEgg.Modules do
			CurrentNest.Clutch[Name] = nil
		end
	end
end

return Nest