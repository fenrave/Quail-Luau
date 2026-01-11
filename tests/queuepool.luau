local Nest = require("../src/Quail")
local Test = zune.testing

local function QueueTest()
	local queue = Nest:NewNest(
		8,
		"Queue"
	)

	queue:AddModule({
		["Test"] = "../tests/testmodules/test"
	})

	local workdef_queue: Nest.Queue = {
		T = 50
	}

	local queue_def: Nest.ThreadDef<typeof(workdef_queue)> = {
		ModuleName = "Test",
		Limit = -1,
		Data = workdef_queue
	}

	local QueueHandler = queue:AssignJob(queue_def)
	queue:OnComplete(QueueHandler.Handle, function(...)
		print("Queue \n",...)
	end)

end

if Test.running then
	Test.test("Multiple Pools", QueueTest)
else
	QueueTest()
end