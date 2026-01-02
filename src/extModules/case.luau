------------------
export type InternalCase = {
    Default: any,
    [any]: any
}

type MetaCase = {
    __call: (Case: Case, Index: any, ...any?) -> ...any,
    __add: (Case: Case, ...any) -> Case
}
------------------

export type Case = setmetatable<InternalCase, MetaCase>

local Cases: {[string]: Case} = {}

local function NewCase(Name: string, Options: InternalCase): Case

    if not Options.Default then
        Options.Default = function()
            return
        end
    end

    local returnCase: Case = setmetatable(
        Options,
        {
            __call = function(Case: Case, Index: any, ...: any): ...any
                if not Case[Index] then
                    if ... then
                        return Case[Index](...)
                    else
                        return Case[Index]
                    end
                end

                if ... then
                    return Case[Index](...)
                else
                    return Case[Index]
                end
            end,
            __add = function(mergeTo: Case, toMerge: Case): Case
                for Index,Key in pairs(toMerge) do
                    mergeTo[Index] = Key
                end
                return (mergeTo :: any) :: Case
            end
        }
    )

    Cases[Name] = returnCase
    return returnCase
end

return NewCase