local Nest = require("../src/Quail")
local Test = zune.testing

local function ParallelTest()

	local parallel = Nest:NewNest(
		12,
		"Parallel"
	)

	local pmodules: Nest.ModuleSetupDef = {
		Nest = parallel,
		Modules = {
			["Test"] = "../tests/testmodules/test"
		}
	}; Nest:AddModule(pmodules)

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

	local parallel_def: Nest.ThreadDef<typeof(workdef_parallel)> = {
		ModuleName = "Test",
		Limit = -1,
		Data = workdef_parallel
	}

	local ParallelHandler = parallel:AssignJob(parallel_def)
	parallel:OnComplete(ParallelHandler.Handle, function(...)
		print("Parallel \n",...)
	end)

end


if Test.running then
	Test.test("Multiple Pools", ParallelTest)
else
	ParallelTest()
end