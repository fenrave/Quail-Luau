local Nest = require("./src/Quail")

local NewNest = Nest:NewNest(
	12, --Amount of threads in the pool
	"Parallel"
) 

local Modules: Nest.ModuleSetupDef = {
	Nest = NewNest,
	Modules = {
		["Test"] = "./example/test"
	}
}

Nest:AddModule(Modules)
Nest.Timer = 1/240

local Data: Nest.Parallel = {
	[1] = {T = 10},
	[2] = {T = 10},
	[3] = {T = 10},
	[4] = {T = 10},
	[5] = {T = 10},
	[6] = {T = 10},
	[7] = {T = 10},
	[8] = {T = 10},
	[9] = {T = 10},
	[10] = {T = 10},
	[11] = {T = 10},
	[12] = {T = 10}
}

-- local Data: Nest.Queue = {
-- 	T = 1
-- }

local Bevy = NewNest:InitBevy("Test")

Bevy["Hello"] = 1

local Def: Nest.EggDef<typeof(Data)> = {
	ModuleName = "Test",
	--Name of initialized module in nest, so the packet knows where to go

	Limit = -1,
	--The amount of times the callback will be called.
	--If desired, -1 will allow it to run indefinitely.

	Type = "Send",
	--List of request types in module under Enums
	--Should only use Send for jobs

	Data = Data
	--The module will be passed this as an arg, so put whatever you want into here
}

local Quail = NewNest:AssignJob(Def)
--Returns a handle that you can use to manipulate the packet with

--[==[
	@Quail:Remove() sets the packet State to 2, destroying the job & handle
	@Quail:Disable() sets the packet State to 1, disabling callbacks
	@Quail:Enable() sets the packet State to 0, enabling callbacks
]==]--

--PacketDef (You can use the returned handle to retrieve this), Callback: (Data) -> ()
NewNest:OnComplete(Quail.Handle, function(ReturnData, ThreadContext)
	Quail.Handle.Data.T = ReturnData.T
	print(Quail.Handle.Data.T)
end)