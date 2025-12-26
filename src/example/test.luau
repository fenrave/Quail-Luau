local QuailTypes = require("../Types.Quail")

type Data = {
    T: number
}

type Shared = {
    Hello: number
}

local function Test(Data: Data, Interface: QuailTypes.ThreadInterface, Context: number): Data
    -- local NewBevy: Shared = Interface.Bevy.Get("Test")

    -- NewBevy["Hello"]  += 1

    Data.T += 10
    
    return Data
end

return Test