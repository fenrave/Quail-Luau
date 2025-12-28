--!strict
local q = require("./Types.Quail")
local Schedulers = require("./Schedulers")
----------------------------------------------------
local Egg = zune.thread
local Task = zune.task
local RGEN: Random = zune.random.new()
local Nest = {} :: q.Nest
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
local ThreadCache: TypedList<number, Thread> = {}

----------------------------------------------------
local function GenID(): number
	local Number = RGEN:nextInteger(1000000000000, 9999999999999)

	if table.find(NumberCache, Number) then
		return GenID()
	end; table.insert(NumberCache, Number)

	return Number
end
----------------------------------------------------
for i = 1, Egg.getCpuCount() do
	local NewEgg = Egg.fromModule("./Burrow") ; NewEgg:start()
	table.insert(ThreadCache, NewEgg)
end

local function GetThreads(Count: number): {Thread}
	local ThreadTable: TypedList<number, Thread> = table.clone(ThreadCache)

	for i: number = 1, #ThreadCache - Count do
		table.remove(ThreadTable, math.random(1, #ThreadTable))
	end; return ThreadTable
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
	end
end; Task.spawn(Nest.Scheduler, Nest)
----------------------------------------------------
function Nest:NewNest(EggAmount: number, SchedType: string?)
	if SchedType == nil then
		SchedType = "Queue"
	end; assert(SchedType ~= nil)

	type SchedType = index<SchedType, SchedType>

	local NewList = {
		Egg = nil :: any,
		Nest = {},
		Clutch = {},
		BevyList = {},
		CurrentEgg = 1
	} :: q.BurrowType

	NewList.InternalScheduler = Schedulers[SchedType]

	NewList.Nest = GetThreads(EggAmount)
	NewList.Egg = NewList.Nest[1]

	local BevyUpdate: q.EggPacket<q.Field> = {
		Data = NewList.BevyList,
		ID = GenID(),
		Name = "Sync",
		RequestAmount = 0,
		RequestType = q.RequestEnum[3]
	}

	local BevyRequest: q.EggPacket<nil> = {
		ID = GenID(),
		Name = "Request",
		RequestAmount = 0,
		RequestType = q.RequestEnum[4]
	}

	local function Internal(): ()
		NewList.InternalScheduler(Schedulers, NewList, BevyUpdate, BevyRequest)
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
		self.Clutch[Handle.Name].Callbacks[Handle.ID] = fn
	end

	function NewList:AssignJob(EggDef: q.EggDef<SchedType>): q.QuailHandle

		local NewPacket: q.EggPacket<SchedType> = {
			Name = EggDef.ModuleName,
			ID = GenID(),
			RequestType = if type(EggDef.Type) ~= "string" then
					q.RequestEnum[EggDef.Type]
				else
					EggDef.Type,
			RequestAmount = EggDef.Limit or -1,
			Data = EggDef.Data,
			State = 0,
			ThreadContext = 0
		}

		NewList.Clutch[EggDef.ModuleName].Jobs[NewPacket.ID] = NewPacket :: EggPacket<any>

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
				ID = GenID(),
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