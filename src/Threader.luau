--!strict
local Thread = zune.thread
local ThreadPool = {} :: ThreadPool
local Task = zune.task
local OS = zune.time
local RGEN = zune.random.new()
----------------------------------------------------
export type ThreadPool = {
	InitNewList: (self: ThreadPool, ThreadAmount: number) -> ThreadType,
	AddThread: (self: ThreadPool, pThread: ThreadProcessDef) -> (),
	RemoveThread: (self: ThreadPool, Name: string) -> (),

	ThreadList: ThreadList
}

export type ThreadProcessDef = {
	Thread: ThreadType,

	Modules: {
		[string]: string
	}
}
----------------------------------------------------

type ThreadInterface = {
	[string]: {
		Jobs: {[number]: ThreadPacket<any>},
		Callbacks: {[number]: ()->()}
	}
}

type BufferPool = {
	[number]: buffer
}

type ThreadType = {
	Thread: Thread,
	ThreadPool: {Thread},
	CurrentThread: number,

	AssignJob: <M>(
		self: ThreadType,
		WorkDef: WorkDef<any>
	) -> JobHandle,
	OnComplete: (
		self: ThreadType,
		ModuleName: string, 
		ID: number, 
		fn: (...any) -> ()
	) -> (),
	NextThread: (self: ThreadType) -> Thread,

	Threads: ThreadInterface
}

type ThreadList = setmetatable<{
	[number]: ThreadType
}, {}> | {}

type ThreadPacket<Assignable> = {
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
local InternalList: ThreadList = {}
ThreadPool.ThreadList = setmetatable({}, {
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
export type JobHandle = {
	Remove: (self: JobHandle) -> (),
	Disable: (self: JobHandle) -> (),
	RequestUpdate: (self: JobHandle) -> (),

	Handle: ThreadPacket<any>
}

----------------------------------------------------
local JobHandle = {} :: JobHandle

local Timer: number = 1/240

function JobHandle:Remove()
	self.Handle.State = 2
	self = nil :: any
end

function JobHandle:Disable()
	self.Handle.State = 1
end
----------------------------------------------------
local CoroutineList: {()->()} = {}

local function GlobalScheduler(): ()
	while CoroutineList do
		for _, Routine in CoroutineList do
			Task.spawn(Routine)
		end

		Task.wait(Timer)
	end
end
Task.defer(GlobalScheduler)
----------------------------------------------------
function ThreadPool:InitNewList(ThreadAmount: number)
	local NewList = {
		Thread = nil :: any,
		ThreadPool = {},
		Threads = {},
		CurrentThread = 1
	} :: ThreadType

	for i = 1, ThreadAmount or 5 do
		local NewThread = Thread.fromModule("./thread_Interface")

		table.insert(
			NewList.ThreadPool,
			NewThread
		); NewThread:start()

	end; NewList.Thread = NewList.ThreadPool[1]

	local function InternalScheduler(): ()
		local self: ThreadType = NewList
		local JobCount: number = 0
		local Thread: Thread = self:NextThread()

		for _, Module in self.Threads do
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

				JobCount += 1
				Thread:send(Job)
			end
		end

		if JobCount > 0 then
			repeat
				JobCount -= 1
				--yields on receive
				local Received: ThreadPacket<CompletedPacket> = Thread:receive()

				local Callback = self.Threads[Received.Name].Callbacks[Received.ID]

				if Callback then
					Callback(Received.Data)
				else
					print(`Unemployed Data on... Module: {Received.Name}, ID: {Received.ID}`)
				end
			until JobCount <= 0
		end
			
	end
table.insert(CoroutineList, InternalScheduler)

	function NewList:NextThread(): Thread
		local NextIndex = self.CurrentThread + 1
		local NextThread: Thread = self.ThreadPool[NextIndex]
		
		if not NextThread then
			NextThread = self.ThreadPool[1]
			NextIndex = 1
		end; self.CurrentThread = NextIndex

		return NextThread
	end

	function NewList:OnComplete(ModuleName: string, ID: number, fn: () -> ()): ()
		self.Threads[ModuleName].Callbacks[ID] = fn
	end

	function NewList:AssignJob<M>(WorkDef: WorkDef<any>): JobHandle
		
		local NewPacket: ThreadPacket<typeof(WorkDef.Data)> = {
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

		NewList.Threads[WorkDef.ModuleName].Jobs[NewPacket.ID] = NewPacket

		local NewHandle = table.clone(JobHandle)
		NewHandle.Handle = NewPacket

		return NewHandle
	end

	InternalList[#InternalList] = NewList

	return NewList
end

function ThreadPool:AddThread(pThread: ThreadProcessDef): ()

	local CurrentThread = pThread.Thread
	for i, Thread in CurrentThread.ThreadPool do
		for Name, Module in pThread.Modules do
			local NewPacket: ThreadPacket<ModulePacket> = {
				Name = Name,
				ID = RGEN:nextInteger(0,9999999999999),
				RequestType = RequestEnum[1],
				RequestAmount = 0,
				Data = {
					Path = Module
				},
				State = 0
			}
	
			CurrentThread.Threads[Name] = {
				Jobs = {},
				Callbacks = {}
			}

			Thread:send(NewPacket)
		end
	end

end

function ThreadPool:RemoveThread()
end


    local Thread = ThreadPool:InitNewList(10)


    local threaddef: ThreadProcessDef = {
        Thread = Thread,
        Modules = {["Test"] = "./modules/test"}
        
    }

    ThreadPool:AddThread(threaddef)

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


return ThreadPool