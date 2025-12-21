local m = zune.thread
local task = zune.task
----------------------------------------------------
type ThreadPacket<Assignable> = {
	Name: string,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number,
	ThreadContext: number
}

type ModuleTable<Module> = {
	[string]: {Module}
}

type Field = {
	[string]: {[any]: any}
}

type Bevy = setmetatable<{}, {
	__index: Field,
	__newindex: Field
}>

type FieldTypes = {
	Fields: Field,

	Bevies: {[string]: Bevy},

	New: (self: FieldTypes, Name: string) -> Field,
	GetBevy: (self: FieldTypes, Name: string) -> Field,
	SyncBevy: (self: FieldTypes, Packet: {
		Data: Field
	}) -> (), 
	GetChanges: (self: FieldTypes) -> Field,

	Data: {
			[string]: {
				[any]: any
			}
	}
}
----------------------------------------------------
type ModulePacket = {
	Path: string?,
	Success: boolean
}

type DataPacket = {
	any
}

type BevyData = Field
----------------------------------------------------
local Field = {
	Fields = {}
} :: FieldTypes 

function Field:New(Name)
	if not self.Fields[Name] then
		self.Fields[Name] = {}
	end
	

	return self.Fields[Name]
end

function Field:GetBevy(Name)
	return self.Fields[Name]
end

function Field:SyncBevy(Packet: ThreadPacket<BevyData>)
	for Index,Value in Packet.Data do
		if not Field.Fields[Index] then
			Field.Fields[Index] = {}
		end
		Field.Fields[Index] = Value
	end
end

function Field:GetChanges()
	return Field.Fields
end

----------------------------------------------------
local ModuleTable = {}

local PacketCase: {
	[string]: (Packet: ThreadPacket<any>) -> ()
} = {
	Module = function(Packet: ThreadPacket<ModulePacket>)
		local ModulePath = Packet.Data.Path
		
		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name][#ModuleTable[Packet.Name]] = require(ModulePath) :: any
	end,

	Send = function(Packet: ThreadPacket<DataPacket>)
		local Modules = ModuleTable[Packet.Name]
		Packet.Data = Modules[math.random(0, #Modules)](Packet.Data, Field, Packet.ThreadContext)

		m.send(Packet)
	end,

	Sync = function(Packet: ThreadPacket<any>)
		Field:SyncBevy(Packet)
	end,

	RequestSync = function()
		m.send(Field:GetChanges())
	end
}

local function Main()
	while true do
		local Packet: ThreadPacket<any> = m.receive()
		task.spawn(PacketCase[Packet.RequestType], Packet)
	end
end; Main()
