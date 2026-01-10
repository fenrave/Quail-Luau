
<img src="src/assets/quail.png" width="256">

## **Quail-Luau**

<sub>Known issue with IO_URING backend, which causes Zune to context switch to a single core. Use environment variable `ZUNE_ASYNC_BACKEND=epoll` if on Linux, which should properly handle it for now. <sub>

<sub>***WIP, First Draft***<sub>

The purpose of this project is to easily create Thread Queues via the Zune Runtime's Thread library.

While multi-threading isn't necessarily the best solution for all problems, inspite of how some people seem to think, easily creating Thread Pool/Queue interfaces can accelerate programs with math heavy code, or take a serious strain off the main thread so less intensive code can execute in its intended manner, especially in an interpreted language context where math isn't particularly efficient, although Luau generally resolves most of that math overhead with native codegen.

Long term goals are to implement differing kinds of ThreadPool back-ends & to improve work sharing between threads.

## Usage

<sub>A working version of this example is present in the repository.<sub>

*Usage Example*

```luau
----------------------------------------
local Quail = require("@Quail")
----------------------------------------
local NewNest = Quail:NewNest(
	12, --Amount of threads in the pool
	"Parallel" --Queue, Parallel
) 

local Modules: Quail.ModuleSetupDef = {
	Nest = NewNest,
	Modules = {
		["Test"] = "./testmodules/test" --path relative from main /src/
	}
}

Quail:AddModule(Modules)
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

local Def: Quail.ThreadDef<Quail.Queue> = {
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

--PacketDef (You can use the returned handle to retrieve this), Callback: (Data) -> ()
NewNest:OnComplete(ThreadHandle.Handle, function(ReturnData, ThreadContext)
	ThreadHandle.Handle.Data.T = ReturnData.T
	print(ReturnData.T)
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