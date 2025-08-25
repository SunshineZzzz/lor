-- Comment: URL路由前缀树节点

local setmetatable = setmetatable
local type = type
local next = next
local ipairs = ipairs
local table_insert = table.insert
local string_lower = string.lower
local string_format = string.format

local utils = require("lor.lib.utils.utils")
local supported_http_methods = require("lor.lib.methods")
local ActionHolder = require("lor.lib.holder").ActionHolder
local handler_error_tip = "handler must be `function` that matches `function(req, res, next) ... end`"
local middlware_error_tip = "middlware must be `function` that matches `function(req, res, next) ... end`"
local error_middlware_error_tip = "error middlware must be `function` that matches `function(err, req, res, next) ... end`"
local node_count = 0

-- 生成唯一节点Id字符串
local function gen_node_id()
	local prefix = "node-"
	local worker_part = "dw"
	if ngx and ngx.worker and ngx.worker.id() then
		worker_part = ngx.worker.id()
	end
	-- simply count for lua vm level
	node_count = node_count + 1
	local unique_part = node_count
	local random_part = utils.random()
	local node_id = prefix .. worker_part  .. "-" .. unique_part .. "-" .. random_part
	return node_id
end

-- HTTP方法是否被支持
local function check_method(method)
	if not method then return false end

	method = string_lower(method)
	if not supported_http_methods[method] then
		return false
	end

	return true
end

-- 路由节点
local Node = {}

-- 新建
function Node:new(root)
	local is_root = false
	if root == true then
		is_root = true
	end

	local instance = {
		-- 节点唯一Id
		id = gen_node_id(),
		-- 是否为trie树根节点
		is_root = is_root,
		-- 动态路由中的参数名称
		name = "",
		-- 当前节点允许的HTTP方法列表，逗号分割字符串
		allow = "",
		-- 当前节点如果结束，记录的完整路由路径
		pattern = "",
		-- 结束标记(完整路由结束标记)
		endpoint = false,
		-- 父亲节点，Node
		parent = nil,
		-- 孩子节点，NodeHolder{key:frag, node:Node{...}}
		children = {},
		-- 当前节点动态路由节点，Node
		colon_child = nil,
		-- 当前节点方法对应的动作(函数)持有者
		-- [http_method]={ActionHolder{}, ..., ActionHolder{}}
		handlers = {},
		-- 中间件持有者集合
		-- {ActionHolder{}, ..., ActionHolder{}}
		middlewares = {},
		-- 错误中间件持有者集合
		-- {ActionHolder{}, ..., ActionHolder{}}
		error_middlewares = {},
		-- 包含正则的动态路由参数，例如:username(^\\w+$)
		regex = nil
	}
	setmetatable(instance, {
		__index = self,
		__tostring = function(s)
			local ok, result = pcall(function()
				return string_format("name: %s", s.id)
			end)
			if ok then
				return result
			else
				return "node.tostring() error"
			end
		end
	})
	return instance
end

-- 根据关键字查找孩子节点
function Node:find_child(key)
	-- print("find_child: ", self.id, self.name, self.children)
	for _, c in ipairs(self.children) do
		if key == c.key then
			return c.val
		end
	end
	return nil
end

-- 当前节点的处理程序列表中是否有指定的HTTP方法
function Node:find_handler(method)
	method = string_lower(method)
	if not self.handlers or not self.handlers[method] or #self.handlers[method] == 0 then
		return false
	end

	return true
end

-- 添加中间件到当前节点
function Node:use(...)
	local middlewares = {...}
	if not next(middlewares) then
		error("middleware should not be nil or empty")
	end

	local empty = true
	for _, h in ipairs(middlewares) do
		if type(h) == "function" then
			local action = ActionHolder:new(h, self, "middleware")
			table_insert(self.middlewares, action)
			empty = false
		elseif type(h) == "table" then
			for _, hh in ipairs(h) do
				if type(hh) == "function" then
					local action = ActionHolder:new(hh, self, "middleware")
					table_insert(self.middlewares, action)
					empty = false
				else
					error(middlware_error_tip)
				end
			end
		else
			error(middlware_error_tip)
		end
	end

	if empty then
		error("middleware should not be empty")
	end

	return self
end

-- 添加错误中间件到当前节点
function Node:error_use(...)
	local middlewares = {...}
	if not next(middlewares) then
		error("error middleware should not be nil or empty")
	end

	local empty = true
	for _, h in ipairs(middlewares) do
		if type(h) == "function" then
			local action = ActionHolder:new(h, self, "error_middleware")
			table_insert(self.error_middlewares, action)
			empty = false
		elseif type(h) == "table" then
			for _, hh in ipairs(h) do
				if type(hh) == "function" then
					local action = ActionHolder:new(hh, self, "error_middleware")
					table_insert(self.error_middlewares, action)
					empty = false
				else
					error(error_middlware_error_tip)
				end
			end
		else
			error(error_middlware_error_tip)
		end
	end

	if empty then
		error("error middleware should not be empty")
	end

	return self
end

-- 添加特定HTTP方法对应处理程序到当前节点
function Node:handle(method, ...)
	method = string_lower(method)
	if not check_method(method) then
		error("error method: ", method or "nil")
	end

	if self:find_handler(method) then
		error("[" .. self.pattern .. "] " .. method .. " handler exists yet!")
	end

	if not self.handlers[method] then
		self.handlers[method] = {}
	end

	local empty = true
	local handlers = {...}
	if not next(handlers) then
		error("handler should not be nil or empty")
	end

	for _, h in ipairs(handlers) do
		if type(h) == "function" then
			local action = ActionHolder:new(h, self, "handler")
			table_insert(self.handlers[method], action)
			empty = false
		elseif type(h) == "table" then
			for _, hh in ipairs(h) do
				if type(hh) == "function" then
					local action = ActionHolder:new(hh, self, "handler")
					table_insert(self.handlers[method], action)
					empty = false
				else
					error(handler_error_tip)
				end
			end
		else
			error(handler_error_tip)
		end
	end

	if empty then
		error("handler should not be empty")
	end

	if self.allow == "" then
		self.allow = method
	else
		self.allow = self.allow .. ", " .. method
	end

	return self
end

-- 返回当前节点允许HTTP方法列表
function Node:get_allow()
	return self.allow
end

-- 移除循环引用等，主要用于可视化或者避免序列化问题
function Node:remove_nested_property(node)
	if not node then return end
	if node.parent then
		node.parent = nil
	end

	if node.colon_child then
		if node.colon_child.handlers then
			for _, h in pairs(node.colon_child.handlers) do
				if h then
					for _, action in ipairs(h) do
						action.func = nil
						action.node = nil
					end
				end
			end
		end
		self:remove_nested_property(node.colon_child)
	end

	local children = node.children
	if children and #children > 0 then
		for _, v in ipairs(children) do
			local c = v.val
			-- remove action func
			if c.handlers then
				for _, h in pairs(c.handlers) do
					if h then
						for _, action in ipairs(h) do
							action.func = nil
							action.node = nil
						end
					end
				end
			end

			self:remove_nested_property(v.val)
		end
	end
end

return Node
