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

function onLoad()
    self.createButton({
        label = "Spawn Pins",
        click_function = "spawnPins",
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

function spawnPins()
    local snaps = self.getSnapPoints()
    if not snaps or #snaps == 0 then
        print("No snap points found on board!")
        return
    end

    local rescale = { ball = 1.5, pin = 1.1 }
    local scale = self.getScale()

    local ballPositions = {
        { -11, 1, 7 },
        { -11, 1, 8 },
    }

    for _, ballPosition in ipairs(ballPositions) do
        spawnObject({
            type = "Metal Ball",
            position = self.positionToWorld(ballPosition),
            scale = { scale.x * rescale.ball, scale.y * rescale.ball, scale.z * rescale.ball },
            callback_function = function(obj)
                obj.setColorTint({ math.random(), math.random(), math.random() })
            end
        })
    end

    for _, snap in ipairs(snaps) do
        spawnObject({
            type = "Custom_Model",
            position = self.positionToWorld(snap.position),
            scale = { scale.x * rescale.pin, scale.y * rescale.pin, scale.z * rescale.pin },
            use_snap_points = true,
        }).setCustomObject({
            type = 1,
            material = 1,
            mesh = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614740757/3BBB5FA45409A0723A9662E53EB4D1A2E09DD727/",
            diffuse = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614215657/4A01683186B1A6E49A2E7558EA9006ABDEE7DF2E/",
            collider = "https://steamusercontent-a.akamaihd.net/ugc/1491209074614740523/6027BD9A9B84B4E3F9C58AF517CB2277619F423B/",
        })
    end
end
