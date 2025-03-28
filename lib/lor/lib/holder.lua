-- Comment: 各种节点定义

local setmetatable = setmetatable
local utils = require("lor.lib.utils.utils")
local ActionHolder = {}

-- 动作(函数)持有者
function ActionHolder:new(func, node, action_type)
	local instance = {
		-- 唯一Id
		id = "action-" .. utils.random(),
		-- 对应路由节点Node
		node = node,
		-- 动作类型字符串
		action_type = action_type,
		-- 绑定函数
		func = func,
	}

	setmetatable(instance, {
		__index = self,
		__call = self.func
	})
	return instance
end

-- 路由节点持有者
local NodeHolder = {}

function NodeHolder:new()
	local instance = {
		-- 路由节点名称
		key = "",
		-- 当前路由节点
		val = nil,
	}
	setmetatable(instance, { __index = self })
	return instance
end

-- 路由匹配到的静态/动态节点
local Matched = {}

function Matched:new()
	local instance = {
		-- 最终匹配到的静态/动态节点
		node = nil,
		-- 动态理由节点的参数集合，比如:":xxx(正则)"中的xxx
		-- xxx - 对应路径字符串
		params = {},
		-- 根节点到node完整路径节点数组
		pipeline = {},
	}
	setmetatable(instance, { __index = self })
	return instance
end

return {
	ActionHolder = ActionHolder,
	NodeHolder = NodeHolder,
	Matched = Matched
}
