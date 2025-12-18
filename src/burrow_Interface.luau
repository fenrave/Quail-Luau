local m = zune.thread
local task = zune.task
----------------------------------------------------
type ThreadPacket<Assignable> = {
	Name: string,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number
}

type ModuleTable<Module> = {
	[string]: {Module}
}

type Field = {
	[string]: {[any]: any}
}

type Bevy = setmetatable<{}, {
	__index: Field,
	__newindex: (List: {}, Index: any, Value: any) -> ()
}>

type FieldTypes = {
	Fields: {
		[string]: {[any]: any}
	},

	Bevies: {[string]: Bevy},

	New: (self: FieldTypes, Name: string) -> Bevy,
	GetBevy: (self: FieldTypes, Name: string) -> Bevy,
	SyncBevy: (self: FieldTypes, 
	Data: {
			[string]: {
				[any]: any
			}
		}
	) -> ()
}
----------------------------------------------------
type ModulePacket = {
	Path: string?,
	Success: boolean
}

type DataPacket = {
	any
}
----------------------------------------------------
local Field = {
	Fields = {}
} :: FieldTypes 

local BevyChanges = {
	Fields = {}
} :: FieldTypes

function Field:New(Name)
	self.Fields[Name] = {}

	local NewBevy: Bevy = setmetatable(
		{},
		{
			__index = self.Fields[Name],
			__newindex = function(List: {}, Index: any, Value: any)
				self.Fields[Index] = Value
				BevyChanges.Fields[Index] = self.Fields[Index]
			end
		}
	)

	self.Bevies[Name] = NewBevy

	return NewBevy
end

function Field:GetBevy(Name)
	return self.Bevies[Name]
end

function Field:SyncBevy(Data)
	for Index,Value in Data do
		self.Fields[Index] = Value
	end
end

----------------------------------------------------
local ModuleTable = {}

local PacketCase = {
	Module = function(Packet: ThreadPacket<ModulePacket>)
		local ReturnState: boolean = false
		local ModulePath = Packet.Data.Path
		
		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name][#ModuleTable[Packet.Name]] = require(ModulePath) :: any

		Packet.Data = {Success = ReturnState}
		return Packet
	end,

	Send = function(Packet: ThreadPacket<DataPacket>)
		local Modules = ModuleTable[Packet.Name]
		Packet.Data = Modules[math.random(0, #Modules)](Packet.Data)

		return Packet
	end
}

local function PassResults(Packet: ThreadPacket<DataPacket>)
	local Result = PacketCase[Packet.RequestType](Packet)

	m.send(Result)
end

local function Main()
	while true do
		local Packet: ThreadPacket<DataPacket> = m.receive()
		task.spawn(PassResults, Packet)
	end
end; Main()
