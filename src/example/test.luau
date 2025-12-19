
type Data = {
    T: number
}

local function Test(Data: Data): Data
    Data.T += 10
    
    return Data
end


return Test