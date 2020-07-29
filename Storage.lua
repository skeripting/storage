local Storage = {
    cacheQueue = {},
    cache = {}
}

local Cache = require(script.cache)(_p)
local Maid = require(script.Maid)

function Storage:resolveArgs(...)
    local t = {}
    for i, v in next, ({...}) do
        if type(v) == "table" then
            table.insert(t, v)
        else
            table.insert(t, {v})
        end
    end
    return t
end

function Storage:clearCacheQueue()
    for i, q in next, self.cacheQueue do
        table.remove(self.cacheQueue, i)
    end
    self.cacheQueue = {}
end

function Storage:attemptCache(folder, ...) --('Battle', {}
    local args = self:resolveArgs(...)
    local cd = {}
    for i, arg in next, args do
        table.insert(self.cacheQueue, arg)
    end
    if not self.cache[folder] then
        self:makeFolder(folder, true)
    end
    for i, arg in next, self.cacheQueue do
        self.cache[folder].cacheData[i] = Cache:new(arg, folder)
    end
    self:clearCacheQueue()
end

function Storage:getCache(folder)
    if self.cache[folder] then
        if not self.cache[folder].cacheData then
            return false
        end
        return self.cache[folder].cacheData
    end
    return false
end

function Storage:makeFolder(folder, cd)
    if not self.cache[folder] then
        self.cache[folder] = {
            exists = true
        }
        if cd then
            self.cache[folder].cacheFolder = true
            self.cache[folder].cacheData = {}
        end
        return self.cache[folder]
    end
    return false
end

function Storage:getMaid()
    return self:getCache("Maid")
end

function Storage:cacheTask(taskName, taskData)
    if taskName and taskData then
        if type(taskName) == "string" then
            local m = self:getMaid()
            if m[taskName] then
                return false
            end
            m[taskName] = taskData
            self:attemptCache("Maid", taskName)
            return true
        end
    end
    return false
end

function Storage:clearFolder(folder, deleteFolder)
    if not self.cache[folder] then
        return false
    end
    if self.cache[folder] then
        if type(self.cache[folder]) == "table" then
            for i, v in next, self.cache[folder] do
                table.remove(self.cache[folder], i)
            end
        end
    end
    if deleteFolder then
        self.cache[folder] = nil
    end
    return true
end

function Storage:lockFolder(folder)
    if _p.debug then
        warn(string.format("attempt to lock folder %s at %s", folder, os.time))
    end
    folder = string.match(folder, "[%s]+")
    if not self.cache[folder] then
        return false
    end
    if self.cache[folder] then
        setmetatable(
            self.cache[folder].cacheData,
            {
                __index = function(self, k, v)
                    return false
                end,
                __newindex = function(self, k, v)
                    return false
                end,
                __metatable = function()
                    return "This folder is locked."
                end
            }
        )
    end
    return true
end

function Storage:cpFolder(folder) --cutPaste
    local nf = {}
    if self.cache[folder] then
        for i, v in next, self.cache[folder] do
            local succ, err
            pcall(
                function()
                    nf[i] = v
                end
            )
            if not succ then
                if _p.debug then
                    warn(string.format("error while cping folder %s: %s"), tostring(folder), tostring(err))
                end
            end
        end
        self.cache[folder] = nil
        self.cache[folder] = nf
    end
end

function Storage:copyFolderContents(folder)
    local nf = {}
    if self.cache[folder] then
        if type(self.cache[folder]) == "table" then
            for i, v in next, self.cache[folder] do
                local succ, err
                pcall(
                    function()
                        nf[i] = v
                    end
                )
                if not succ then
                    if _p.debug then
                        warn(
                            string.format("error while copying folder %s's contents: %s"),
                            tostring(folder),
                            tostring(err)
                        )
                    end
                end
            end
        end
    end
end

function Storage:unlockFolder(folder)
    if self.cache[folder] then
        local s, e =
            pcall(
            function()
                getmetatable(self.cache[folder])
            end
        )
        if e then
            return false --attempt to unlock a folder that was not locked
        end
    end

    if _p.debug then
        warn(string.format("attempt to unlock folder %s at %s", folder, os.time))
        warn("warning: cannot unlock folder with locked metatable -> copying contents to another + replacing")
    end
    if self.cache[folder] then
        self:cpFolder(folder)
    end
end

function Storage:blockCacheRequests()
    local mt_blocked = {
        __newindex = function(self, k, v)
            return false
        end
    }
    for i, folder in next, self.cache do
        setmetatable(folder, mt_blocked)
    end
    setmetatable(self.cache, mt_blocked)
end

function Storage:permitCacheRequests()
    local mt = getmetatable(self.cache)
    if not mt then
        return
    end
    local mt_unblocked = {
        __newindex = function(self, k, v)
            rawset(self[k], v) --can i even do this
            return self[k]
        end
    }
    for i, folder in next, self.cache do
        setmetatable(folder, mt_unblocked)
    end
    setmetatable(self.cache, mt_unblocked)
end

function Storage:rawRequestCache(folder, index) --temporary bypass
    if self.cache[folder] then
        return rawget(self.cache[folder].cacheData, index)
    end
end

function Storage:runRecursive(tab, fn)
    local function check(v, fn)
        if type(v) ~= "table" then
            return false
        end
        if type(fn) ~= "function" then
            return false
        end
    end
    local function recurse(v, fn)
        if check(v, fn) == false then
            return false
        end
        for i, v in next, v do
            if check(v, fn) == false then
                return false
            end
            recurse(v, fn)
        end
    end
    recurse(tab, fn)
end

function Storage:getTick(folder)
    local lt = tick()
    if folder then
        if self.cache[folder] then
            for i, v in next, self.cacheFolder do
                --do nothing
            end
            return tick() - lt
        end
    else
        self:runRecursive(
            self.cache,
            function()
                --do nothing
            end
        )
        return tick() - lt
    end
end

function Storage:debugContents()
    if _p.debug then
        _p.Utilities.print_r(self.cache)
    end
end

--Maid setup
local maid = Maid.new()
Storage:attemptCache("Maid", maid)

return Storage
