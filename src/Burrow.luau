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
local BevyList: {Flock: {q.Field}} = {Flock = {}}
----------------------------------------------------
local Field = {} :: q.FieldTypes
local ThreadContext: number = 0
----------------------------------------------------
function Field.Get(Name, Meta)
	if not BevyList.Flock[ThreadContext] then
		BevyList.Flock[ThreadContext] = {}
	end

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

function Field:SyncBevy(Packet: q.ThreadPacket<Bevy>)	
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
local ReceivedQueue: {q.ThreadPacket<any>} = {}
local ToSendQueue: {q.ThreadPacket<any>} = {}

local PacketCase: q.TypedList<string, (Packet: q.ThreadPacket<any>) -> ()> = {
	MODULE = function(Packet: q.ThreadPacket<q.ModulePacket>)		
		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name] = require(Packet.Data.Path) :: any
	end,

	SEND = function(Packet: q.ThreadPacket<q.DataPacket>)
		ThreadContext = Packet.ThreadContext :: number
		Packet.Data = ModuleTable[Packet.Name](
			Packet.Data, 
			{Bevy = Field, Covy = Covy, ToggleFlush = ToggleCovyFlush}, 
			Packet.ThreadContext
		); table.insert(ToSendQueue, Packet)
	end,

	SYNC = function(Packet: q.ThreadPacket<any>)
		ThreadContext = Packet.ThreadContext :: number
		if DoFlush then
			Covy:flush()
		end; Field:SyncBevy(Packet)
	end,

	REQUESTSYNC = function(Packet: q.ThreadPacket<any>)
		Packet.Data = Field:GetChanges() ; table.insert(ToSendQueue, Packet)
	end
}

local function SendQueueHandler(): ()
	while true do coroutine.yield()
		repeat
			local Packet = ReceivedQueue[1] ; table.remove(ReceivedQueue, 1)
			PacketCase[Packet.RequestType](Packet)
		until #ReceivedQueue == 0
	end
end

local Handler = coroutine.create(SendQueueHandler) ; coroutine.resume(Handler)

local function Main(): ()
	while true do
		local Packet: q.ThreadPacket<any> = m.receive()
		table.insert(ReceivedQueue, Packet)

		if coroutine.status(Handler) == "suspended" then
			task.spawn(Handler)
		end

		for Index: number, nPacket in ToSendQueue do
			m.send(nPacket)
		end; table.clear(ToSendQueue)
	end
end; Main()
