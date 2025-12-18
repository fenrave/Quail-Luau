local m = zune.thread
local task = zune.task

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

type ModulePacket = {
	Path: string
}

type DataPacket = {
	any
}

local ModuleTable = {}

local PacketCase = {
	Module = function(Packet: ThreadPacket<ModulePacket>): boolean
		local ReturnState: boolean = false
		local ModulePath = Packet.Data.Path

		if not ModuleTable[Packet.Name] then
			ModuleTable[Packet.Name] = {}
		end

		ModuleTable[Packet.Name][#ModuleTable[Packet.Name]] = require(ModulePath) :: any

		return ReturnState
	end,

	Send = function(Packet: ThreadPacket<DataPacket>)
		local Modules = ModuleTable[Packet.Name]

		return Modules[math.random(0, #Modules)](Packet.Data)
	end
}

local function PassResults(Packet: ThreadPacket<DataPacket>)
	local Result = PacketCase[Packet.RequestType](Packet)

	m.send(Packet)
end

local function Main()
	while true do
		local Packet: ThreadPacket<DataPacket> = m.receive()
		task.spawn(PassResults, Packet)
	end
end; Main()
