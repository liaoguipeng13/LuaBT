local BehaviourTree = bt.Class("BehaviourTree")
bt.BehaviourTree = BehaviourTree

function BehaviourTree:ctor()
    self.id = 0
    self.type = nil
    self.name = "BehaviourTree"
    self.primeNode = nil
    self.nodes =  {}
    self.nodesIndex = {}
    self.rootStatus = bt.Status.Resting
    self.agent = nil
    self.blackboard = nil
    self.isRunning = false
    self.isPaused = false
    self.isRepeat = true
    self.tickCount = 0
end

function BehaviourTree:start()
    self.rootStatus = self.primeNode.status
end

function BehaviourTree:update()
    if self:tick(self.agent, self.blackboard) ~= bt.Status.Running and 
        not self.isRepeat then
        self.stop(self.rootStatus == bt.Status.Success)
    end
end

function BehaviourTree:tick(agent, blackboard)
    if self.rootStatus ~= bt.Status.Running then
        self.tickCount = self.tickCount + 1
        --print("bt tick:"..self.tickCount.."-------------"..bt.getStatusInfo(self.rootStatus))
        self.primeNode:reset()
    end
    self.rootStatus = self.primeNode:execute(agent, blackboard)
    return self.rootStatus
end

function BehaviourTree:stop(success)
    if not self.isRunning and not self.isPaused then
        return
    end
    self.isRunning = false
    self.isPaused = false
    for k, node in pairs(self.nodes)do
        node:reset(false)
        node:onGraphStoped()
    end
end

function BehaviourTree:pause()
    if not self.isRunning then
        return
    end
    self.isRunning = false
    self.isPaused = true
    for k, node in pairs(self.nodes)do
        node:onGraphPaused()
    end
end

function BehaviourTree:load(fileName)
    local path = bt.ASSERT_DIR .. fileName .. bt.ASSERT_SUFFIX
    print("load bt:"..path)
    local file = io.open(path, "r")
    if file == nil then
        print("ERROR:BehaviourTree:load can't open file:".. path)
        return
    end
    local jsonData = file:read("*a")
    local data = bt.decodeJson(jsonData)
    self.version = data.version
    self.type = data.type
    self.name = fileName
    local spec, id, type, node, Cls
    
    for i, v in pairs(data.nodes) do
        spec = v
        id = tonumber(spec["$id"])
        if id ~= nil then--不在树中的节点没有id
            Cls = bt.getCls(spec["$type"], spec)
            node = Cls.new()
            node.id = id
            node.comment = spec["_comment"]
            node:init(spec)
            --action
            if node.isActionNode then
                if spec["_action"] == nil then
                    print("ERROR:node not contain action : id="..id..",node="..node.name)
                else
                    Cls = bt.getCls(spec["_action"]["$type"], spec)
                    local action = Cls.new()
                    action:init(spec["_action"])
                    node.action = action
                end
            end
            --condition
            if node.isConditionNode then
                if spec["_condition"] == nil then
                    print("ERROR:node not contain condition : id="..id..",node="..node.name)
                else
                    Cls = bt.getCls(spec["_condition"]["$type"], spec)
                    local condition = Cls.new()
                    condition:init(spec["_condition"])
                    node.condition = condition
                end
            end
            --subtree
            if node.isSubTreeNode then
                local subTreeId = spec._subTree._value
                local subTreePath = spec._subTreePath._value
                if subTreeId ~= nil and subTreePath ~= nil then
                    node.subTree = self:createSubTree(i, subTreePath)
                end
            end
            self.nodes[id] = node
            table.insert(self.nodesIndex, id)
        end
    end
    --connections
    for i, v in pairs(data.connections) do
        spec = v
        Cls = bt.getCls(spec["$type"], spec)
        local sourceNodeId = tonumber(spec["_sourceNode"]["$ref"])
        local targetNodeId = tonumber(spec["_targetNode"]["$ref"])
        local isDisabled = false
        if spec["_isDisabled"] then
            isDisabled = true
        end
        local sourceNode = self.nodes[sourceNodeId]
        local targetNode = self.nodes[targetNodeId]
        local connection = Cls.new()
        connection:create(i, sourceNode, targetNode, isDisabled)
        targetNode:addInConnection(connection)
        sourceNode:addOutConnection(connection)
    end
    --primeNode
    local primeNodeId = tonumber(data["primeNode"]["$ref"])
    self.primeNode = self.nodes[primeNodeId]
end