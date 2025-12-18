[Quail Image](/quail.png)

## **Quail-Luau**

The purpose of this project is to easily create ThreadPools via the Zune Runtime's Thread library.

While multi-threading isn't necessarily the best solution for all problems, inspite of how some people seem to think, easily creating ThreadPool interfaces can quickly accelerate math heavy code, especially in an interpreted language context.

Or alternatively, code that doesn't need to run on the main thread, or particularly often, can be offloaded to a secondary thread, so long as there's data to be processed.

## Usage

*Usage Example*

```luau
local Nest = require("@Nest") --Assuming aliased, if not, path directly

local NewNest = Nest:NewNest(4) --Amount of threads in the pool

local Eggs: EggSetupDef = {
    Nest = NewNest,
    Modules = {
        ["modulename"] = "./path/to/module"
    }
}

Nest:AddEgg(Eggs)

local NewBuffer: buffer = buffer.create(10)

buffer.writef64(NewBuffer, 0, 10)

local Data = { T = NewBuffer }

local Def: EggDef<typeof(Data)> = {
    ModuleName = "modulename",
    --Name of initialized module in nest, so the packet knows where to go

    Limit = -1,
    --The amount of times the callback will be called.
    --If desired, -1 will allow it to run indefinitely.

    Type = "Send",
    --List of request types in module under Enums

    Data = Data
    --The module will be passed this as an arg, so put whatever you want into here
}

local Quail = NewNest:AssignTask(Def)
--Returns a handle that you can use to manipulate the packet with

--[++[
    @Quail:Remove() sets the packet State to 2, destroying the job & handle
    @Quail:Disable() sets the packet State to 1, disabling callbacks
    @Quail:Enable() sets the packet State to 0, enabling callbacks
]++]--

--ModuleName, PacketID, Callback: (Data) -> ()
NewNest:OnComplete("Test", Quail.Handle.ID, function(Data)
    print(buffer.readf64(Data.T, 0)
end)
```

*"Why all these tables?"*

All data is expected to be reused & set up once.

You could build a definitions file for all of the data you're going to need, or make boilerplates you can `table.clone(def)` from.

The idea here is to have everything running constantly and to creating

*Minimal Receiving module side*
```luau
local function returnData(Data: {T: Buffer})
    buffer.writef64(Data.T, 0, 50)

    return Data
end


return returnData
```
