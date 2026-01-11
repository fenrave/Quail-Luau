local Nest = require("../src/Quail")
local Test = zune.testing


local function MultiPoolTest()
	local queue = Nest:NewNest(
		8,
		"Queue"
	)

	local parallel = Nest:NewNest(
		12,
		"Parallel"
	)

	queue:AddModule({
		["Test"] = "../tests/testmodules/test"
	})

	parallel:AddModule({
		["Test"] = "../tests/testmodules/test"
	})

	local workdef_queue: Nest.Queue = {
		T = 50
	}

	local workdef_parallel: Nest.Parallel = {
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20},
		{T = 20}
	}

	local queue_def: Nest.ThreadDef<typeof(workdef_queue)> = {
		ModuleName = "Test",
		Limit = -1,
		Data = workdef_queue
	}

	local parallel_def: Nest.ThreadDef<typeof(workdef_parallel)> = {
		ModuleName = "Test",
		Limit = -1,
		Data = workdef_parallel
	}

	local QueueHandler = queue:AssignJob(queue_def)
	queue:OnComplete(QueueHandler.Handle, function(...)
		print("Queue \n",...)
	end)

	local ParallelHandler = parallel:AssignJob(parallel_def)
	parallel:OnComplete(ParallelHandler.Handle, function(...)
		print("Parallel \n",...)
	end)

end

if Test.running then
	Test.test("Multiple Pools", MultiPoolTest)
else
	MultiPoolTest()
end