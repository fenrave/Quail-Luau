local Nest = require("./src/Quail")


local NewNest = Nest:NewNest(5) --Amount of threads in the pool

local Eggs: Nest.EggSetupDef = {
    Nest = NewNest,
    Modules = {
        ["Test"] = "./example/test"
    }
}

Nest:AddEgg(Eggs)

local num: number = 5



local Data = { T = num }

local Def: Nest.EggDef<typeof(Data)> = {
    ModuleName = "Test",
    --Name of initialized module in nest, so the packet knows where to go

    Limit = -1,
    --The amount of times the callback will be called.
    --If desired, -1 will allow it to run indefinitely.

    Type = "Send",
    --List of request types in module under Enums

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

--ModuleName, PacketID, Callback: (Data) -> ()
NewNest:OnComplete("Test", Quail.Handle.ID, function(ReturnData)

    Quail.Handle.Data.T = ReturnData.T
    -- print("quaildata", Quail.Handle.Data)
end)