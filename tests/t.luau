----------------------------------------
local Quail = require("../src/Quail")
----------------------------------------
local NewNest = Quail:NewNest(
	32, --Amount of threads in the pool
	"Parallel" --Queue, Parallel
) 

NewNest:AddModule({
	["Test"] = "../tests/testmodules/test"
})

Quail.Timer = 1/240

local Data: Quail.Parallel = {
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
--Initialize a bevy, which works as a shared table with the Queue backend
local Bevy = NewNest:InitBevy("Test")

Bevy["Hello"] = 1

Bevy:Sync()

local Def: Quail.ThreadDef<Quail.Parallel> = {
	ModuleName = "Test",
	--Name of initialized module in nest, so the packet knows where to go

	Limit = -1,
	--The amount of times the callback will be called.
	--If desired, -1 will allow it to run indefinitely.

	Data = Data
	--The module will be passed this as an arg, so put whatever you want into here
}

local ThreadHandle = NewNest:AssignJob(Def)
--Returns a handle that you can use to manipulate the packet with

--[==[
	@Quail:Remove() sets the packet State to 2, destroying the job & handle
	@Quail:Disable() sets the packet State to 1, disabling callbacks
	@Quail:Enable() sets the packet State to 0, enabling callbacks
]==]--

--Callback: (Data) -> ()
ThreadHandle:OnComplete(function(ReturnData, ThreadContext)
	ThreadHandle.Handle.Data.T = ReturnData.T
	print(ReturnData.T)
end)
--Alternatively
NewNest:OnComplete(ThreadHandle.Handle, function(ReturnData, ThreadContext)
	print(ThreadContext)
end)