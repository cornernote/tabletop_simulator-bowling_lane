local Base = {
    name = "Bowling Lane",
    debug = false,
    host = self,
    print = function(self, message)
        print(self.name .. ": " .. message)
    end,
    error = function(self, message)
        if self.debug then
            error(self.name .. ": " .. message)
        end
    end,
    reload = function(self)
        Wait.condition(function()
            return not self.host or self.host.reload()
        end, function()
            return not self.host or self.host.resting
        end)
    end
}

local AutoUpdate  = setmetatable({
    version = "1.0.0",
    versionUrl = "https://raw.githubusercontent.com/cornernote/tabletop_simulator-bowling_lane/refs/heads/main/lua/bowling-lane.ver",
    scriptUrl = "https://raw.githubusercontent.com/cornernote/tabletop_simulator-bowling_lane/refs/heads/main/lua/bowling-lane.lua",

    run = function(self)
        WebRequest.get(self.versionUrl, function(request)
            if request.response_code ~= 200 then
                self:error("Failed to check version (" .. request.response_code .. ": " .. request.error .. ")")
                return
            end
            local remoteVersion = request.text:match("[^\r\n]+") or ""
            if self:isNewerVersion(remoteVersion) then
                self:fetchNewScript(remoteVersion)
            end
        end)
    end,
    isNewerVersion = function(self, remoteVersion)
        local function split(v)
            return { v:match("^(%d+)%.?(%d*)%.?(%d*)") or 0 }
        end
        local r, l = split(remoteVersion), split(self.version)
        for i = 1, math.max(#r, #l) do
            local rv, lv = tonumber(r[i]) or 0, tonumber(l[i]) or 0
            if rv ~= lv then
                return rv > lv
            end
        end
        return false
    end,
    fetchNewScript = function(self, newVersion)
        WebRequest.get(self.scriptUrl, function(request)
            if request.response_code ~= 200 then
                self:error("Failed to fetch new script (" .. request.response_code .. ": " .. request.error .. ")")
                return
            end
            if request.text and #request.text > 0 then
                self.host.setLuaScript(request.text)
                self:print("Updated to version " .. newVersion)
                self:reload()
            else
                self:error("New script is empty")
            end
        end)
    end,
}, { __index = Base })

local pins = { }
local balls = { }

function onLoad()
    self.createButton({
        label = "Setup Lane",
        click_function = "setupLane",
        function_owner = self,
        position = { 0, 0.1, 9.3 },
        rotation = { 0, 0, 0 },
        scale = { 3, 1, 1 },
        width = 2000,
        height = 300,
        font_size = 200,
    })

    AutoUpdate:run()
end

function setupLane()
    cleanupPins()
    cleanupBalls()
    spawnPins()
    spawnBalls()
end

function cleanupPins()
    for i = #pins, 1, -1 do
        local obj = getObjectFromGUID(pins[i])
        if obj then
            destroyObject(obj)
        end
    end
    pins = {}
end

function cleanupBalls()
    for i = #balls, 1, -1 do
        local obj = getObjectFromGUID(balls[i])
        if obj then
            destroyObject(obj)
        end
    end
    balls = {}
end

function spawnBalls()
    local rescale = 1.5
    local scale = self.getScale()
    local ballPositions = {
        { -11, 1, 7 },
        { -11, 1, 8 },
    }

    for _, ballPosition in ipairs(ballPositions) do
        local ball = spawnObject({
            type = "Metal Ball",
            position = self.positionToWorld(ballPosition),
            scale = { scale.x * rescale, scale.y * rescale, scale.z * rescale },
            callback_function = function(ball)
                ball.setColorTint({ math.random(), math.random(), math.random() })
                ball.setLuaScript([[
                    local dropPosY = nil
                    function onDropped()
                        local pos = self.getPosition()
                        Wait.time(function()
                            dropPosY = self.getPosition().y
                        end, 0.2)
                    end
                    function onUpdate()
                        if dropPosY and self.getPosition().y < dropPosY - 0.1 then
                            Wait.time(function()
                                destroyObject(self)
                            end, 1)
                        end
                    end
                ]])
            end
        })

        table.insert(balls, ball.getGUID())
    end
end

function spawnPins()
    local rescale = 1.1
    local scale = self.getScale()
    local snaps = self.getSnapPoints()

    for _, snap in ipairs(snaps) do
        local pin = spawnObject({
            type = "Custom_Model",
            position = self.positionToWorld(snap.position),
            scale = { scale.x * rescale, scale.y * rescale, scale.z * rescale },
            use_snap_points = true,
        })

        pin.setCustomObject({
            type = 1,
            material = 1,
            mesh = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614740757/3BBB5FA45409A0723A9662E53EB4D1A2E09DD727/",
            diffuse = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614215657/4A01683186B1A6E49A2E7558EA9006ABDEE7DF2E/",
            collider = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614740523/6027BD9A9B84B4E3F9C58AF517CB2277619F423B/",
        })

        pin.setLuaScript([[
            function onUpdate()
                if math.abs(self.getTransformUp().y) < 0.8 then
                    Wait.time(function()
                        destroyObject(self)
                    end, 1)
                end
            end
        ]])

        table.insert(pins, pin.getGUID())
    end
end

-- Global.getVar('Encoder') -- comment needed to prevent mtg pi table falsely detecting this as a game-crashing or virus-infected object