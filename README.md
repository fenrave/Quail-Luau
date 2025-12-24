
<img src="src/assets/quail.png" width="256">

## **Quail-Luau**

<sub>***WIP, First Draft***<sub>

The purpose of this project is to easily create Thread Queues via the Zune Runtime's Thread library.

While multi-threading isn't necessarily the best solution for all problems, inspite of how some people seem to think, easily creating Thread Pool/Queue interfaces can accelerate programs with math heavy code, or take a serious strain off the main thread so less intensive code can execute in its intended manner, especially in an interpreted language context where math isn't particularly efficient, although Luau generally resolves most of that math overhead with native codegen.

Long term goals are to implement differing kinds of ThreadPool back-ends & to improve work sharing between threads.

## Usage

<sub>A working version of this example is present in the repository.<sub>

*Usage Example*

```luau
local Nest = require("@Nest") --Assuming aliased, if not, path directly

local NewNest = Nest:NewNest(5) --Amount of threads in the pool/queue

local Modules: Nest.ModuleSetupDef = {
	Nest = NewNest,
	Modules = {
		["Test"] = "./example/test"
	}
}

Nest:AddModule(Modules)

local num: number = 5

local Data: Nest.Dict = { T = num }

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
NewNest:OnComplete(Quail.Handle, function(ReturnData)
	Quail.Handle.Data.T = ReturnData.T
	print(Quail.Handle.Data.T)
end)
```

<sub>*"Why all these tables?"*<sub>

All data is expected to be reused & set up once.

You could build a definitions file for all of the data you're going to need, or make boilerplates you can `table.clone(def)` from.

The idea here is to have everything running constantly. Data is updated in real time and it's up to you to handle how much you want it to update.

*Minimal Receiving module side*

```luau
local QuailTypes = require("@Types.Quail")

type Data = {
    T: number
}

--Context is the current execution thread
local function Test(Data: Data, Interface: QuailTypes.ThreadInterface, Context: number): Data
    local NewBevy = Interface.Bevy.Get("Test")

    NewBevy["Hello"]  += 1

    Data.T += 10
    
    return Data
end


return Test
```
## Scheduler

Overriding the scheduler and tying it into your own is fairly easy.

**Scheduler Timer**

This is as simple as changing the `Nest.Timer` to something else.

Zune allows task.wait() to run in terms of nanoseconds (0.0001~), so you're not tied to a specific frequency. Default is 240hz (1/240).


**Replacing the Scheduler**

You can either call `Nest:ToggleScheduler()` or toggle `Nest.NoInternalScheduler = true` manually. From there, you can then either replace the Nest:Scheduler() method, or iterate over the `Nest.RoutineList` and invoke the internal schedulers directly.