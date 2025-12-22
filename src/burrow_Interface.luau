local m = zune.thread
local task = zune.task
local q = require("./Types.Quail")
----------------------------------------------------
type Bevy = q.Field
----------------------------------------------------
local Covy: BufferSink = zune.io.createBufferSink(
	{size = 1024} :: BufferSinkOptions
)
----------------------------------------------------
local BevyList = {Flock = {} :: q.Field}

local Field = {} :: q.FieldTypes 

function Field.Get(Name)
	if not BevyList.Flock[Name] then
		BevyList.Flock[Name] = {}
	end

	return BevyList.Flock[Name]
end

function Field:SyncBevy(Packet:  q.ThreadPacket<Bevy>)
	for Index,Value in Packet.Data do
		if not BevyList.Flock[Index] then
			BevyList.Flock[Index] = {}
		end; BevyList.Flock[Index] = Value
	end
end

function Field:GetChanges()
	return BevyList.Flock
end
----------------------------------------------------
local ModuleTable = {}

local PacketCase: {
	[string]: (Packet:  q.ThreadPacket<any>) -> ()
} = {
	Module = function(Packet: q.ThreadPacket<q.ModulePacket>)
		local ModulePath = Packet.Data.Path
		
		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name] = require(ModulePath) :: any
	end,

	Send = function(Packet:  q.ThreadPacket<q.DataPacket>)
		Packet.Data = ModuleTable[Packet.Name](
			Packet.Data, 
			{Bevy = Field, Covy = Covy}, 
			Packet.ThreadContext
		); m.send(Packet)
	end,

	Sync = function(Packet:  q.ThreadPacket<any>)
		Covy:flush()
		Field:SyncBevy(Packet)
	end,

	RequestSync = function()
		m.send(Field:GetChanges())
	end
}

local function Main()
	while true do
		local Packet:  q.ThreadPacket<any> = m.receive()
		task.spawn(PacketCase[Packet.RequestType], Packet)
	end
end; Main()
