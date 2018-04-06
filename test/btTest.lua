local function includePath()
    local paths = {
        "C:/work/project/LuaBT/bt/?.lua",
        "C:/work/project/XGame/XCommon/lua/?.lua",
    }
    for k,path in pairs(paths) do
        package.path = package.path .. ";" .. path
    end
end

includePath()
require("btHeader")
require("lib.driver")

local btree = bt.BehaviourTree.new()
btree:load("test")

local function updateBT()
    bt.time = bt.time + bt.deltaTime
    btree:update()
end
xd.addTimer(0,bt.deltaTime * 1000,updateBT)