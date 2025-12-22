local q = require("../Types.Quail")

type Data = {
    T: number
}

local function Test(Data: Data, Sys: q.ThreadIncl, Context: number): Data
    local NewBevy = Sys.Bevy.Get("Test")

    NewBevy["Hello"]  += 1

    Data.T += 10
    
    return Data
end


return Test