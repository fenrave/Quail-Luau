
type Data = {
    T: buffer
}

local function Test(Data: Data): Data
    buffer.writef64(Data.T, 0, buffer.readf64(Data.T, 0) + 10)
    
    return Data
end


return Test