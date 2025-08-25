-- Comment: URL路由前缀树

local setmetatable = setmetatable
local tonumber = tonumber
local string_lower = string.lower
local string_find = ngx.re.find
local string_sub = string.sub
local string_gsub = ngx.re.gsub
local string_len = string.len
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat

local utils = require("lor.lib.utils.utils")
local holder = require("lor.lib.holder")
local Node = require("lor.lib.node")
local NodeHolder = holder.NodeHolder
local Matched = holder.Matched
local mixin = utils.mixin
local valid_segment_tip = "valid path should only contains: [A-Za-z0-9._%~-]"

-- 路由路径是否包含合法字符
local function check_segment(segment)
	local tmp = string_gsub(segment, "([A-Za-z0-9._%~-]+)", "", "jo")
	if tmp ~= "" then
		return false
	end
	return true
end

-- 检查新的动态路由节点是否与父节点的动态路由节点发生冲突
local function check_colon_child(node, colon_child)
	if not node or not colon_child then
		return false, nil
	end

	-- 只有一个不一样就说明冲突
	if node.name ~= colon_child.name or node.regex ~= colon_child.regex then
		return false, colon_child
	end

	-- could be added
	return true, nil
end

-- 在父节点查找，找不到创建新的
local function get_or_new_node(parent, frag, ignore_case)
	if not frag or frag == "/" or frag == "" then
		frag = ""
	end

	if ignore_case == true then
		frag = string_lower(frag)
	end

	local node = parent:find_child(frag)
	if node then
		return node
	end

	node = Node:new()
	node.parent = parent

	if frag == "" then
		local nodePack = NodeHolder:new()
		nodePack.key = frag
		nodePack.val = node
		table_insert(parent.children, nodePack)
	else
		local first = string_sub(frag, 1, 1)
		-- 是否包含动态参数
		if first == ":" then
			local name = string_sub(frag, 2)
			local trailing = string_sub(name, -1)

			-- 是否包含正则，例如:username(^\\w+$)
			if trailing == ')' then
				local index = string_find(name, "\\(", "jo")
				if index and index > 1 then
					local regex = string_sub(name, index+1, #name-1)
					if #regex > 0 then
						name = string_sub(name, 1, index-1)
						node.regex = regex
					else
						error("invalid pattern[1]: " .. frag)
					end
				end
			end

			local is_name_valid = check_segment(name)
			if not is_name_valid then
				error("invalid pattern[2], illegal path:" .. name .. ", " .. valid_segment_tip)
			end
			node.name = name

			-- /user/home/house
			-- /user/home/house/:name
			-- /user/home/house/:id(^\\d+$)
			-- 这两者只能是其中一个，所以下面需要做一些冲突判断
			local colon_child = parent.colon_child
			if colon_child then
				local valid, conflict = check_colon_child(node, colon_child)
				if not valid then
					error("invalid pattern[3]: [" .. name .. "] conflict with [" .. conflict.name .. "]")
				else
					return colon_child
				end
			end

			parent.colon_child = node
		else
			local is_name_valid = check_segment(frag)
			if not is_name_valid then
				error("invalid pattern[6]: " .. frag .. ", " .. valid_segment_tip)
			end

			local nodePack = NodeHolder:new()
			nodePack.key = frag
			nodePack.val = node
			table_insert(parent.children, nodePack)
		end
	end

	return node
end

-- 插入节点，如果存在就返回该节点
local function insert_node(parent, frags, ignore_case)
	local frag = frags[1]
	local child = get_or_new_node(parent, frag, ignore_case)

	if #frags >= 1 then
		table_remove(frags, 1)
	end

	if #frags == 0 then
		child.endpoint = true
		return child
	end

	return insert_node(child, frags, ignore_case)
end

-- 返回从根节点到该节点的完整路径节点
local function get_pipeline(node)
	local pipeline = {}
	if not node then return pipeline end

	local tmp = {}
	local origin_node = node
	table_insert(tmp, origin_node)
	while node.parent
	do
		table_insert(tmp, node.parent)
		node = node.parent
	end

	for i = #tmp, 1, -1 do
		table_insert(pipeline, tmp[i])
	end

	return pipeline
end

-- URL路由前缀树，优先匹配静态路由，实在匹配不到再进行动态路由匹配
local Trie = {}

-- 新建
function Trie:new(opts)
	opts = opts or {}
	local trie = {
		-- 路由匹配时，回退查找最大深度
		max_fallback_depth = 100,

		-- URI中允许的最大路径段数 e.g. a long uri, /a/b/c/d/e/f/g/h/i/j/k...
		max_uri_segments = 100,

		-- 是否无视大小写
		ignore_case = true,

		-- 路由匹配是否严格
		-- [true]: "test.com/" is not the same with "test.com".
		-- [false]: "test.com/" will match "test.com/" first, then try to math "test.com" if not exists 
		strict_route = true,

		-- URL路由前缀树根节点
		root = Node:new(true)
	}

	trie.max_fallback_depth = tonumber(opts.max_fallback_depth) or trie.max_fallback_depth
	trie.max_uri_segments = tonumber(opts.max_uri_segments) or trie.max_uri_segments
	trie.ignore_case = opts.ignore_case or trie.ignore_case
	trie.strict_route = not (opts.strict_route == false)

	setmetatable(trie, {
		__index = self,
		__tostring = function(s)
			return string_format("Trie, ignore_case:%s strict_route:%s max_uri_segments:%d max_fallback_depth:%d",
				s.ignore_case, s.strict_route, s.max_uri_segments, s.max_fallback_depth)
		end
	})

	return trie
end

-- URL路由前缀树添加路由节点
function Trie:add_node(pattern)
	pattern = utils.trim_path_spaces(pattern)

	if string_find(pattern, "//", "jo") then
		error("`//` is not allowed: " ..  pattern)
	end

	local tmp_pattern = utils.trim_prefix_slash(pattern)
	local tmp_segments = utils.split(tmp_pattern, "/")

	local node = insert_node(self.root, tmp_segments, self.ignore_case)
	if node.pattern == "" then
		node.pattern = pattern
	end

	return node
end

-- 给定的父节点下寻找与给定路径段匹配的动态节点
function Trie:get_colon_node(parent, segment)
	local child = parent.colon_child
	if child and child.regex and not utils.is_match(segment, child.regex) then
		-- 有正则但是不匹配
		child = nil
	end
	return child
end

-- 回溯匹配，在动态路由集合栈中(fallback_stack)匹配路由路径集合(segments)
-- params - 动态路由节点的参数集合，比如:":xxx(正则)"中的xxx，xxx - 对应路径字符串
-- return - 回溯匹配动态节点或者false
function Trie:fallback_lookup(fallback_stack, segments, params)
	if #fallback_stack == 0 then
		return false
	end

	-- 取出栈顶，后进先出，从最近的、最可能匹配成功的回退点开始尝试
	local fallback = table_remove(fallback_stack, #fallback_stack)
	local segment_index = fallback.segment_index
	local parent = fallback.colon_node
	local matched = Matched:new()

	-- fallback to the colon node and fill param if matched
	if parent.name ~= "" then
		matched.params[parent.name] = segments[segment_index]
	end
	-- mixin params parsed before
	mixin(params, matched.params)

	local flag = true
	for i, s in ipairs(segments) do
		if i <= segment_index then
			-- 目的是跳过前面已经处理过的路径
			-- continue
		else
			local node, colon_node, is_same = self:find_matched_child(parent, s)
			if self.ignore_case and node == nil then
				node, colon_node, is_same = self:find_matched_child(parent, string_lower(s))
			end

			if colon_node and not is_same then
				-- save colon node to fallback stack
				table_insert(fallback_stack, {
					segment_index = i,
					colon_node = colon_node
				})
			end

			-- both exact child and colon child is nil
			if node == nil then
				-- should not set parent value
				flag = false
				break
			end

			parent = node
		end
	end

	if flag and parent.endpoint then
		matched.node = parent
		matched.pipeline = get_pipeline(parent)
	end

	if matched.node then
		return matched
	else
		return false
	end
end

-- 给定的父节点下寻找与给定路径段匹配的子节点和动态节点
-- 返回: 精确匹配的静态节点，动态节点，表示前两者是否为同一个(只有动态节点的情况下为true)
function Trie:find_matched_child(parent, segment)
	local child = parent:find_child(segment)
	local colon_node = self:get_colon_node(parent, segment)

	if child then
		if colon_node then
			return child, colon_node, false
		else
			return child, nil, false
		end
	else
		-- not child
		if colon_node then
			-- 后续不再压栈
			return colon_node, colon_node, true
		else
			return nil, nil, false
		end
	end
end

-- 匹配
function Trie:match(path)
	if not path or path == "" then
		error("`path` should not be nil or empty")
	end

	path = utils.slim_path(path)

	local first = string_sub(path, 1, 1)
	if first ~= '/' then
		error("`path` is not start with prefix /: " .. path)
	end

	-- special case: regard "test.com" as "test.com/"
	if path == "" then
        path = "/"
    end

	local matched = self:_match(path)
	if not matched.node and self.strict_route ~= true then
		-- retry to find path without last slash
		if string_sub(path, -1) == '/' then
			matched = self:_match(string_sub(path, 1, -2))
		end
	end

	return matched
end

-- 私有，匹配实现
function Trie:_match(path)
	local start_pos = 2
	local end_pos = string_len(path) + 1
	local segments = {}
	-- should set max depth to avoid attack
	for i=2, end_pos, 1 do
		if i < end_pos and string_sub(path, i, i) ~= '/' then
			-- continue
		else
			local segment = string_sub(path, start_pos, i-1)
			table_insert(segments, segment)
			start_pos = i + 1
		end
	end

	-- whether to continue to find matched node or not
	local flag = true
	local matched = Matched:new()
	local parent = self.root
	local fallback_stack = {}
	for i, s in ipairs(segments) do
		local node, colon_node, is_same = self:find_matched_child(parent, s)
		if self.ignore_case and node == nil then
			node, colon_node, is_same = self:find_matched_child(parent, string_lower(s))
		end

		-- print(i)
		-- print(table.concat(segments, '/'))
		-- print(s)
		-- print(node==nil)
		-- print(colon_node==nil)
		-- print(is_same)
		-- print(i)

		-- 优先匹配静态路由，实在匹配不到再进行动态路由匹配
		-- 存在动态和静态匹配，先把动态存储起来
		if colon_node and not is_same then
			table_insert(fallback_stack, {
				segment_index = i,
				colon_node = colon_node
			})
		end

		-- 说明无论是静态路由还是动态路由都没有匹配到
		-- both exact child and colon child is nil
		if node == nil then
			-- should not set parent value
			flag = false
			break
		end

		parent = node
		-- 不为空，说明是动态路由节点，需要把参数保存起来
		if parent.name ~= "" then
			matched.params[parent.name] = s
		end
	end

	-- 都为true，说明确实匹配到了
	if flag and parent.endpoint then
		matched.node = parent
	end

	local params = matched.params or {}
	-- 没有精确匹配，只能在动态路由中进行回溯匹配
	if not matched.node then
		local depth = 0
		local exit = nil

		while not exit do
			depth = depth + 1
			if depth > self.max_fallback_depth then
				error("fallback lookup reaches the limit: " .. self.max_fallback_depth)
			end

			exit = self:fallback_lookup(fallback_stack, segments, params)
			if exit then
				matched = exit
				break
			end

			if #fallback_stack == 0 then
				break
			end
		end
	end

	matched.params = params
	if matched.node then
		matched.pipeline = get_pipeline(matched.node)
	end

	return matched
end

-- 移除内部属性，简化节点，为图形表示做准备
--- only for dev purpose: pretty json preview
-- must not be invoked in runtime
function Trie:remove_nested_property(node)
	if not node then return end
	if node.parent then
		-- 避免序列化的时候循环引用
		node.parent = nil
	end
	if node.handlers then
		for _, h in pairs(node.handlers) do
			if h then
				for _, action in ipairs(h) do
					action.func = nil
					action.node = nil
				end
			end
		end
	end
	if node.middlewares then
		for _, m in pairs(node.middlewares) do
			if m then
				m.func = nil
				m.node = nil
			end
		end
	end
	if node.error_middlewares then
		for _, m in pairs(node.error_middlewares) do
			if m then
				m.func = nil
				m.node = nil
			end
		end
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
		if node.colon_child.middlewares then
			for _, m in pairs(node.colon_child.middlewares) do
				if m then
					m.func = nil
					m.node = nil
				end
			end
		end
		if node.colon_child.error_middlewares then
			for _, m in pairs(node.colon_child.error_middlewares) do
				if m then
					m.func = nil
					m.node = nil
				end
			end
		end
		self:remove_nested_property(node.colon_child)
	end

	local children = node.children
	if children and #children > 0 then
		for _, v in ipairs(children) do
			local c = v.val
			if c.handlers then -- remove action func
				for _, h in pairs(c.handlers) do
					if h then
						for _, action in ipairs(h) do
							action.func = nil
							action.node = nil
						end
					end
				end
			end
			if c.middlewares then
				for _, m in pairs(c.middlewares) do
					if m then
						m.func = nil
						m.node = nil
					end
				end
			end
			if c.error_middlewares then
				for _, m in pairs(c.error_middlewares) do
					if m then
						m.func = nil
						m.node = nil
					end
				end
			end

			self:remove_nested_property(v.val)
		end
	end
end

-- 图形显示
--- only for dev purpose: graph preview
-- must not be invoked in runtime
function Trie:gen_graph()
	local cloned_trie = utils.clone(self)
	cloned_trie:remove_nested_property(cloned_trie.root)
	local result = {"graph TD",  cloned_trie.root.id .. "((root))"}

	local function recursive_draw(node, res)
		if node.is_root then node.key = "root" end

		local colon_child = node.colon_child
		if colon_child then
			table_insert(res, node.id .. "-->" .. colon_child.id .. "(:" .. colon_child.name .. "<br/>" .. colon_child.id .. ")")
			recursive_draw(colon_child, res)
		end

		local children = node.children
		if children and #children > 0 then
			for _, v in ipairs(children) do
				if v.key == "" then
					-- table_insert(res, node.id .. "-->" .. v.val.id .. "[*EMPTY*]")
					local text = {node.id, "-->", v.val.id, "(<center>", "*EMPTY*", "<br/>", v.val.id, "</center>)"}
					table_insert(res, table_concat(text, ""))
				else
					local text = {node.id, "-->", v.val.id, "(<center>", v.key, "<br/>", v.val.id, "</center>)"}
					table_insert(res, table_concat(text, ""))
				end
				recursive_draw(v.val, res)
			end
		end
	end

	recursive_draw(cloned_trie.root, result)
	return table.concat(result, "\n")
end

return Trie
