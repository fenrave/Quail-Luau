--!strict
local Egg = zune.thread
local Nest = {} :: Nest
local Task = zune.task
local RGEN = zune.random.new()
----------------------------------------------------
export type Nest = {
	NewNest: (self: Nest, EggAmount: number) -> BurrowType,
	AddEgg: (self: Nest, pEgg: EggSetupDef) -> (),
	RemoveEgg: (self: Nest, Name: string) -> (),

	Scheduler: (self: Nest) -> (),
	RoutineList: {() -> ()},
	ToggleScheduler: (self: Nest) -> (),

	NoInternalSchedule: boolean,

	Timer: number,
	EggList: EggList
}

export type EggSetupDef = {
	Nest: BurrowType,

	Modules: {
		[string]: string
	}
}
----------------------------------------------------

type EggInterface = {
	[string]: {
		Jobs: {[number]: EggPacket<any>},
		Callbacks: {[number]: ()->()}
	}
}

type BufferPool = {
	[number]: buffer
}

type BurrowType = {
	Egg: Thread,
	Nest: {Thread},
	CurrentEgg: number,

	AssignJob: <M>(
		self: BurrowType,
		EggDef: EggDef<any>
	) -> QuailHandle,
	OnComplete: (
		self: BurrowType,
		ModuleName: string, 
		ID: number, 
		fn: (...any) -> ()
	) -> (),
	NextEgg: (self: BurrowType) -> Thread,

	Eggs: EggInterface
}

type EggList = setmetatable<{
	[number]: BurrowType
}, {}> | {}

type EggPacket<Assignable> = {
	Name: string,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number
}

export type EggDef<Type> = {
	ModuleName: string,
	Limit: number,
	Type: string,
	Data: Type
}

type CompletedPacket = {
	any
}

type ModulePacket = {
	Path: string
}
----------------------------------------------------
local InternalList: EggList = {}
Nest.EggList = setmetatable({}, {
		__index = InternalList,
		__newindex = InternalList
	}
)

local RequestEnum: {string} = {
	[1] = "Module",
	[2] = "Send",
	[3] = "Request"
}
----------------------------------------------------
export type QuailHandle = {
	Remove: (self: QuailHandle) -> (),
	Disable: (self: QuailHandle) -> (),
	Enable: (self: QuailHandle) -> (),

	Handle: EggPacket<any>
}

----------------------------------------------------
local QuailHandle = {} :: QuailHandle


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

function Nest:ToggleScheduler()
	Nest.NoInternalSchedule = not Nest.NoInternalSchedule --Inverts state
end

function Nest:Scheduler(): ()
	while not Nest.NoInternalSchedule do
		for _, Routine in self.RoutineList do
			Routine()
		end

		Task.wait(self.Timer)
	end
end
Task.spawn(Nest.Scheduler, Nest)
----------------------------------------------------
function Nest:NewNest(EggAmount: number)
	local NewList = {
		Egg = nil :: any,
		Nest = {},
		Eggs = {},
		CurrentEgg = 1
	} :: BurrowType

	for i: number = 1, EggAmount or 5 do
		local NewEgg: Thread = Egg.fromModule("./burrow_Interface")

		table.insert(
			NewList.Nest,
			NewEgg
		); NewEgg:start()

	end; NewList.Egg = NewList.Nest[1]

	local function InternalScheduler(): ()
		local self: BurrowType = NewList
		local JobCount: number = 0
		local Egg: Thread = self:NextEgg()
		for _, Module in self.Eggs do
			for Index, Job in Module.Jobs do
				if Job.State == 2 or Job.RequestAmount == 0 then
					Module.Jobs[Index] = nil
					continue
				elseif Job.State == 1 then
					continue
				end
				print("jobdata",Job.Data)
				Job.RequestAmount = if Job.RequestAmount > 0 then
										Job.RequestAmount - 1 
									else 
										-1
					
				JobCount += 1 ; Egg:send(Job)
			end
		end

		if JobCount > 0 then
			repeat JobCount -= 1;
				--yields on receive
				local Received: EggPacket<CompletedPacket> = Egg:receive()
				print("receiveddata", Received.Data)
				local Callback = self.Eggs[Received.Name].Callbacks[Received.ID]

				if Callback then
					Callback(Received.Data)
				else
					print(`Orphaned Data on... Module: {Received.Name}, ID: {Received.ID}`)
				end
			until JobCount <= 0
		end
			
	end ; table.insert(self.RoutineList, InternalScheduler)

	function NewList:NextEgg(): Thread
		local NextIndex = self.CurrentEgg + 1
		local NextEgg: Thread = self.Nest[NextIndex]
		
		if not NextEgg then
			NextEgg = self.Nest[1]
			NextIndex = 1
		end; self.CurrentEgg = NextIndex

		self.Egg = NextEgg
		return NextEgg
	end

	function NewList:OnComplete(ModuleName: string, ID: number, fn: () -> ()): ()
		self.Eggs[ModuleName].Callbacks[ID] = fn
	end

	function NewList:AssignJob<M>(EggDef: EggDef<any>): QuailHandle
		
		local NewPacket: EggPacket<typeof(EggDef.Data)> = {
			Name = EggDef.ModuleName,
			ID = RGEN:nextInteger(0,9999999999999),
			RequestType = if type(EggDef.Type) ~= "string" then
					RequestEnum[EggDef.Type]
				else
					EggDef.Type,
			RequestAmount = EggDef.Limit or -1,
			Data = EggDef.Data,
			State = 0
		}

		NewList.Eggs[EggDef.ModuleName].Jobs[NewPacket.ID] = NewPacket

		local NewHandle = table.clone(QuailHandle)
		NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[#InternalList] = NewList

	return NewList
end

function Nest:AddEgg(pEgg: EggSetupDef): ()

	local CurrentNest = pEgg.Nest
	for i, Egg in CurrentNest.Nest do
		for Name, Module in pEgg.Modules do
			local NewPacket: EggPacket<ModulePacket> = {
				Name = Name,
				ID = RGEN:nextInteger(0,9999999999999),
				RequestType = RequestEnum[1],
				RequestAmount = 0,
				Data = {
					Path = Module
				},
				State = 0
			}
	
			CurrentNest.Eggs[Name] = {
				Jobs = {},
				Callbacks = {}
			}

			Egg:send(NewPacket)
		end
	end

end

function Nest:RemoveEgg()
end



return Nest