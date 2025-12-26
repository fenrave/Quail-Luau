local m = zune.thread
local task = zune.task
local q = require("./Types.Quail")
----------------------------------------------------
type Bevy = q.Field
----------------------------------------------------
local Covy: BufferSink = zune.io.createBufferSink(
	{size = 2048} :: BufferSinkOptions
)
local DoFlush: boolean = false
local function ToggleCovyFlush()
	DoFlush = not DoFlush
end
----------------------------------------------------
local BevyList: {Flock: q.Field} = {Flock = {}}

local Field = {} :: q.FieldTypes 



function Field.Get(Name)
	if not BevyList.Flock[Name] then
		BevyList.Flock[Name] = {}
	end
	
	local Bevy = BevyList.Flock[Name]

	return Bevy :: q.Dict
end

function Field:SyncBevy(Packet:  q.EggPacket<Bevy>)
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

local PacketCase: q.TypedList<string, (Packet: q.EggPacket<any>) -> ()> = {
	Module = function(Packet: q.EggPacket<q.ModulePacket>)
		local ModulePath = Packet.Data.Path
		
		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name] = require(ModulePath) :: any
	end,

	Send = function(Packet: q.EggPacket<q.DataPacket>)
		Packet.Data = ModuleTable[Packet.Name](
			Packet.Data, 
			{Bevy = Field, Covy = Covy, ToggleFlush = ToggleCovyFlush}, 
			Packet.ThreadContext
		); m.send(Packet)
	end,

	Sync = function(Packet: q.EggPacket<any>)
		if DoFlush then
			Covy:flush()
		end; Field:SyncBevy(Packet)
	end,

	RequestSync = function()
		m.send(Field:GetChanges())
	end
}

local function Main(): ()
	while true do
		local Packet: q.EggPacket<any> = m.receive()
		task.spawn(PacketCase[Packet.RequestType], Packet)
	end
end; Main()
