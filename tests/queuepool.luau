local Nest = require("../src/Quail")
local Test = zune.testing

local function QueueTest()
	local queue = Nest:NewNest(
		8,
		"Queue"
	)

	local qmodule: Nest.ModuleSetupDef = {
		Nest = queue,
		Modules = {
			["Test"] = "./testmodules/test"
		}
	}; Nest:AddModule(qmodule)

	local workdef_queue: Nest.Queue = {
		T = 50
	}

	local queue_def: Nest.EggDef<typeof(workdef_queue)> = {
		ModuleName = "Test",
		Limit = -1,
		Data = workdef_queue
	}

	local QueueHandler = queue:AssignJob(queue_def)
	queue:OnComplete(QueueHandler.Handle, function(...)
		print("Queue \n",...)
	end)

end

Test.test("Multiple Pools", QueueTest)