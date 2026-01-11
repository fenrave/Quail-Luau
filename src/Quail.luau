--!strict
local q = require("./Types.Quail")
local Schedulers = require("./Schedulers")
local InitModule = require("./Initializers")
local Initializers = InitModule.Initializers
local Passer = InitModule.PassList 
----------------------------------------------------
local Task = zune.task
local RGEN: Random = zune.random.new()
local Nest = {} :: q.Quail ; Passer(Nest)
----------------------------------------------------
export type ModuleSetupDef = q.ModuleSetupDef
export type ThreadDef<Def> = q.ThreadDef<Def>
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
type ThreadPacket<Def> = q.ThreadPacket<Def>
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
local InternalList: q.NestList = {}
Nest.NestList = setmetatable({}, {
		__index = InternalList,
		__newindex = InternalList
	}
)

Nest.RoutineList = {}
Nest.Timer = 1/240
Nest.NoInternalSchedule = false
Nest.ThreadLimit = 32
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

function QuailHandle:OnComplete(fn: (...any) -> ())
	local Handle = self.Handle

	Nest.NestList[Handle.NestID]:OnComplete(Handle, fn)
end
----------------------------------------------------
function Nest:ToggleScheduler()
	Nest.NoInternalSchedule = not Nest.NoInternalSchedule --Inverts state
end

function Nest:Scheduler(): ()
	Initializers.Setup(Nest.ThreadLimit)
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
function Nest:NewNest(ThreadAmount: number, SchedType: string?)
	if SchedType == nil then
		SchedType = "Queue"
	end; assert(SchedType ~= nil)

	ThreadAmount = math.clamp(ThreadAmount, 1, #Initializers.ThreadCache)

	local NewList = {
		Egg = nil :: any,
		Nest = {} :: any,
		Clutch = {},
		BevyList = {},
		CurrentThread = 1,
		NestID = GenID(),
		SchedType = SchedType
	} :: q.BurrowType
	
	NewList.InternalScheduler = Schedulers[SchedType]

	NewList.Nest = Initializers["Default"](Initializers, NewList, ThreadAmount, NewList.NestID)
	NewList.Thread = NewList.Nest[1]

	NewList.BevyUpdate = {
		Data = NewList.BevyList,
		NestID = NewList.NestID,
		ID = GenID(),
		Name = "BEVYSYNC",
		RequestAmount = 0,
		RequestType = q.RequestEnum[3]
	}

	NewList.BevyRequest = {
		NestID = NewList.NestID,
		ID = GenID(),
		Name = "BEVYREQUEST",
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

	function NewList:SyncBevies()
		self.BevyUpdate.Data = self.BevyList
		for Index, Thread in self.Nest do
			local TID = tonumber(tostring(self.NestID..Index))
			self.BevyUpdate.ThreadContext = TID :: number
			Thread:send(self.BevyUpdate)
		end
	end

	function NewList:AddModule(Def)
		for i, Egg in self.Nest do
			for Name, ModulePath in Def do
				local NewPacket: q.ThreadPacket<q.ModulePacket> = {
					Name = Name,
					ID = GenID(),
					NestID = self.NestID,
					RequestType = string.upper(q.RequestEnum[1]),
					RequestAmount = 0 :: number,
					Data = {
						Path = ModulePath
					},
					State = 0
				}

				self.Clutch[Name] = {
					Jobs = {},
					Callbacks = {}
				}

				Egg:send(NewPacket)
			end
		end

	end

	function NewList:NextThread(): Thread
		local NextIndex: number = self.CurrentThread + 1
		local NextThread: Thread = self.Nest[NextIndex]

		if not NextThread then
			NextThread = self.Nest[1]
			NextIndex = 1
		end; self.CurrentThread = NextIndex

		self.Thread = NextThread ; return NextThread
	end

	function NewList:OnComplete(Handle, fn: <Type>(...Type) -> ()): ()
		local List = self.Clutch[Handle.Name].Callbacks

		if not List[Handle.ID] then
			List[Handle.ID] = {}
		end

		List[Handle.ID][GenID()] = fn
	end

	function NewList:AssignJob(ThreadDef: ThreadDef<DataPacket>): q.QuailHandle
		local NewPacket: q.ThreadPacket<DataPacket> = {
			Name = ThreadDef.ModuleName,
			ID = GenID(),
			NestID = NewList.NestID,
			RequestType = q.RequestEnum[2],
			RequestAmount = ThreadDef.Limit or -1,
			Data = ThreadDef.Data,
			State = 0,
			ThreadContext = 0
		}
		NewPacket.RequestType = string.upper(NewPacket.RequestType)

		if not NewList.Clutch[ThreadDef.ModuleName] then
			error("Module wasn't loaded, or failed to load before assignment.")
		end

		NewList.Clutch[ThreadDef.ModuleName].Jobs[NewPacket.ID] = NewPacket :: ThreadPacket<any>

		local NewHandle = table.clone(QuailHandle) ; NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[NewList.NestID] = NewList

	return NewList
end


return Nest