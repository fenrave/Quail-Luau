--!strict
local Egg = zune.thread
local Nest = {} :: Nest
local Task = zune.task
local OS = zune.time
local RGEN = zune.random.new()
----------------------------------------------------
export type Nest = {
	InitNewList: (self: Nest, EggAmount: number) -> EggType,
	AddEgg: (self: Nest, pEgg: EggProcessDef) -> (),
	RemoveEgg: (self: Nest, Name: string) -> (),

	EggList: EggList
}

export type EggProcessDef = {
	Egg: EggType,

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

type EggType = {
	Egg: Thread,
	Nest: {Thread},
	CurrentEgg: number,

	AssignJob: <M>(
		self: EggType,
		WorkDef: WorkDef<any>
	) -> QuailHandle,
	OnComplete: (
		self: EggType,
		ModuleName: string, 
		ID: number, 
		fn: (...any) -> ()
	) -> (),
	NextEgg: (self: EggType) -> Thread,

	Eggs: EggInterface
}

type EggList = setmetatable<{
	[number]: EggType
}, {}> | {}

type EggPacket<Assignable> = {
	Name: string,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number
}

export type WorkDef<Type> = {
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
	RequestUpdate: (self: QuailHandle) -> (),

	Handle: EggPacket<any>
}

----------------------------------------------------
local QuailHandle = {} :: QuailHandle

local Timer: number = 1/240

function QuailHandle:Remove()
	self.Handle.State = 2
	self = nil :: any
end

function QuailHandle:Disable()
	self.Handle.State = 1
end
----------------------------------------------------
local RoutineList: {()->()} = {}

local function GlobalScheduler(): ()
	while RoutineList do
		for _, Routine in RoutineList do
			Routine()
		end

		Task.wait(Timer)
	end
end
Task.defer(GlobalScheduler)
----------------------------------------------------
function Nest:InitNewList(EggAmount: number)
	local NewList = {
		Egg = nil :: any,
		Nest = {},
		Eggs = {},
		CurrentEgg = 1
	} :: EggType

	for i: number = 1, EggAmount or 5 do
		local NewEgg: Thread = Egg.fromModule("./burrow_Interface")

		table.insert(
			NewList.Nest,
			NewEgg
		); NewEgg:start()

	end; NewList.Egg = NewList.Nest[1]

	local function InternalScheduler(): ()
		local self: EggType = NewList
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

				local Callback = self.Eggs[Received.Name].Callbacks[Received.ID]

				if Callback then
					Callback(Received.Data)
				else
					print(`Unemployed Data on... Module: {Received.Name}, ID: {Received.ID}`)
				end
			until JobCount <= 0
		end
			
	end ; table.insert(RoutineList, InternalScheduler)

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

	function NewList:AssignJob<M>(WorkDef: WorkDef<any>): QuailHandle
		
		local NewPacket: EggPacket<typeof(WorkDef.Data)> = {
			Name = WorkDef.ModuleName,
			ID = RGEN:nextInteger(0,9999999999999),
			RequestType = if type(WorkDef.Type) ~= "string" then
					RequestEnum[WorkDef.Type]
				else
					WorkDef.Type,
			RequestAmount = WorkDef.Limit or -1,
			Data = WorkDef.Data,
			State = 0
		}

		NewList.Eggs[WorkDef.ModuleName].Jobs[NewPacket.ID] = NewPacket

		local NewHandle = table.clone(QuailHandle)
		NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[#InternalList] = NewList

	return NewList
end

function Nest:AddEgg(pEgg: EggProcessDef): ()

	local CurrentEgg = pEgg.Egg
	for i, Egg in CurrentEgg.Nest do
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
	
			CurrentEgg.Eggs[Name] = {
				Jobs = {},
				Callbacks = {}
			}

			Egg:send(NewPacket)
		end
	end

end

function Nest:RemoveEgg()
end


    local Thread = Nest:InitNewList(10)


    local threaddef: EggProcessDef = {
        Egg = Thread,
        Modules = {["Test"] = "./modules/test"}
        
    }

    Nest:AddEgg(threaddef)

	local NewBuffer = buffer.create(10)
	buffer.writef64(NewBuffer, 0, 10)

	local Def = {
		ModuleName = "Test", 
		Limit = -1, 
		Type = "Send", 
		Data = {x = NewBuffer}
	}

    local Handle = Thread:AssignJob(Def)
	local Timer = os.clock()

    Thread:OnComplete("Test", Handle.Handle.ID, function(output: {x: buffer})
		buffer.writef64(NewBuffer, 0, buffer.readf64(NewBuffer, 0) + 10)
		print(buffer.readf64(output.x, 0))
		if buffer.readf64(output.x, 0) == 2000000 then
			print(os.clock() - Timer)
			zune.process.exit(0)
		end
    end)


return Nest