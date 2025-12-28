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
local BevyList: {Flock: {q.Field}} = {Flock = table.create(m.getCpuCount(), table.clone({}))}
----------------------------------------------------
local Field = {} :: q.FieldTypes
local ThreadContext: number = 0
----------------------------------------------------
function Field.Get(Name, Meta)
	if not BevyList.Flock[ThreadContext][Name] then
		BevyList.Flock[ThreadContext][Name] = {}
	end
	
	local Flock = BevyList.Flock[ThreadContext][Name]
	local Bevy = Flock
	if Meta then
		Bevy = setmetatable({},
		{
			__index = function(_, Index: any): any
				if not Flock[Index] then
					Flock[Index] = 0
				end; return Flock[Index]
			end,

			__newindex = function(_, Index: any, Value: any): ()
				if not Flock[Index] then
					Flock[Index] = Value ; return
				end

				Flock[Index] = Value
			end
		})
	end

	return Bevy :: q.Dict
end

function Field:SyncBevy(Packet: q.EggPacket<Bevy>)
	for Index,Value in Packet.Data do
		if not BevyList.Flock[ThreadContext] then
			BevyList.Flock[ThreadContext] = {}
		end

		if not BevyList.Flock[ThreadContext][Index] then
			BevyList.Flock[ThreadContext][Index] = {}
		end; BevyList.Flock[ThreadContext][Index] = Value
	end
end

function Field:GetChanges()
	return BevyList.Flock[ThreadContext]
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
		ThreadContext = Packet.ThreadContext :: number
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
