type Data = {
    x: buffer
}

local function Test(Data: Data): Data
    buffer.writef64(Data.x, 0, buffer.readf64(Data.x, 0) + 10)
    
    return Data
end


return Test