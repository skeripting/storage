local function class(nc, newf) --SCRIPT: I did not make this function
    nc = nc or {}
    nc.__index = nc
    local classDebugData
    function nc:new(o, ...)
        o = o or {}
        if type(o) == "table" and not getmetatable(o) then
            setmetatable(o, nc)
        end
        if newf then
            o = newf(o, ...) or o
        end
        if type(o) == "table" and not getmetatable(o) then
            setmetatable(o, nc)
        end
        if classDebugData then
            table.insert(classDebugData.instances, o)
        end
        return o
    end
    return nc
end

local cache =
    class(
    {},
    function(cd, folder)
        if not cd or not folder then
            return
        end
        local self = {}
        self.timestamp = os.time()
        self.metadata = cd
        self.folder = folder
        self.mt = {
            __index = function(self, k, v)
                if not self[k] then
                    if self.metadata[k] then
                        return self.metadata[k]
                    end
                end
                return self[k]
            end,
            __metatable = function()
                return false
            end
        }
        setmetatable(self.metadata, self.mt)
        return self
    end
)

return cache
