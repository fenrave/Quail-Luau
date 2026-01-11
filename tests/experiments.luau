----------------------------------------
local Nest = require("../src/Quail")
local Test = zune.testing
local out = zune.io.stdout
----------------------------------------
local NewNest = Nest:NewNest(
	12, --Amount of threads in the pool
	"Parallel"
)

NewNest:AddModule({
	["Test"] = "../tests/testmodules/test"
})

Nest.Timer = 1/800

local Data1: Nest.Parallel = {
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

local Data2: Nest.Parallel = {
	[1] = {T = 5},
	[2] = {T = 10},
	[3] = {T = 10},
	[4] = {T = 3},
	[5] = {T = 10},
	[6] = {T = 10},
	[7] = {T = 1},
	[8] = {T = 10},
	[9] = {T = 10},
	[10] = {T = 5},
	[11] = {T = 10},
	[12] = {T = 10}
}

-- local Data: Nest.Queue = {
-- 	T = 1
-- }

local Bevy = NewNest:InitBevy("Test")

Bevy["Hello"] = 1

local Def1: Nest.ThreadDef<Nest.Parallel> = {
	ModuleName = "Test",
	--Name of initialized module in nest, so the packet knows where to go

	Limit = -1,
	--The amount of times the callback will be called.
	--If desired, -1 will allow it to run indefinitely.

	Data = Data1
	--The module will be passed this as an arg, so put whatever you want into here
}

local Def2 = table.clone(Def1)

local Quail1 = NewNest:AssignJob(Def1)
local Quail2 = NewNest:AssignJob(Def2)
--Returns a handle that you can use to manipulate the packet with

--[==[
	@Quail:Remove() sets the packet State to 2, destroying the job & handle
	@Quail:Disable() sets the packet State to 1, disabling callbacks
	@Quail:Enable() sets the packet State to 0, enabling callbacks
]==]--

--PacketDef (You can use the returned handle to retrieve this), Callback: (Data) -> ()

local Target = 0

for i = 1, 5 do
	NewNest:OnComplete(Quail1.Handle, function(ReturnData: {T: number}, ThreadContext)
		Target += ReturnData.T
	end)

	NewNest:OnComplete(Quail2.Handle, function(ReturnData: {T: number}, ThreadContext)
		Target += ReturnData.T
	end)
end


NewNest:OnComplete(Quail1.Handle, function(ReturnData, ThreadContext)
	-- print("AAAA")
end)
