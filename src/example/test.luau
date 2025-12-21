
type Data = {
    T: number
}

local function Test(Data: Data, Bevy, Context: number): Data
    local NewBevy = Bevy:New("Test")

    if not NewBevy["Hello"] then
        NewBevy["Hello"] = 1
    end

    NewBevy["Hello"] += 1
    print(NewBevy["Hello"], `ThreadContext {Context}`)
    Data.T += 10
    
    return Data
end


return Test