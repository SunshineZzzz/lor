-- Comment: HTTP响应封装

local pairs = pairs
local type = type
local setmetatable = setmetatable
local tinsert = table.insert
local tconcat = table.concat
local utils = require("lor.lib.utils.utils")

local Response = {}

-- 创建
function Response:new()
	local instance = {
		http_status = nil,
		headers = {},
		locals = {},
		body = '--default body. you should not see this by default--',
		view = nil
	}

	setmetatable(instance, { __index = self })
	return instance
end

-- 渲染html网页并且响应内容
function Response:render(view_file, data)
	if not self.view then
		ngx.log(ngx.ERR, "`view` object is nil, maybe you disabled the view engine.")
		error("`view` object is nil, maybe you disabled the view engine.")
	else
		self:set_header('Content-Type', 'text/html; charset=UTF-8')
		data = data or {}
		-- inject res.locals
		data.locals = self.locals

		local body = self.view:render(view_file, data)
		self:_send(body)
	end
end

-- 直接响应html网页内容
function Response:html(data)
	self:set_header('Content-Type', 'text/html; charset=UTF-8')
	self:_send(data)
end

-- 直接响应json内容
function Response:json(data, empty_table_as_object)
	self:set_header('Content-Type', 'application/json; charset=utf-8')
	self:_send(utils.json_encode(data, empty_table_as_object))
end

-- 重定向
function Response:redirect(url, code, query)
	if url and not code and not query then
		--  It is 302 ("ngx.HTTP_MOVED_TEMPORARILY") by default.
		ngx.redirect(url)
	elseif url and code and not query then
		if type(code) == "number" then
			ngx.redirect(url, code)
		elseif type(code) == "table" then
			query = code
			local q = {}
			local is_q_exist = false
			if query and type(query) == "table" then
				for i,v in pairs(query) do
					tinsert(q, i .. "=" .. v)
					is_q_exist = true
				end
			end

			if is_q_exist then
				url = url .. "?" .. tconcat(q, "&")
			end

			ngx.redirect(url)
		else
			ngx.redirect(url)
		end
	else
		local q = {}
		local is_q_exist = false
		if query and type(query) == "table" then
		   for i,v in pairs(query) do
			   tinsert(q, i .. "=" .. v)
			   is_q_exist = true
		   end
		end

		if is_q_exist then
			url = url .. "?" .. tconcat(q, "&")
		end
		ngx.redirect(url ,code)
	end
end

-- rewrite regrex replacement [last/break];
function Response:location(url, data)
	if data and type(data) == "table" then
		ngx.req.set_uri_args(data)
		-- rewrite ^ /foo last;
		-- 等价于
		-- ngx.req.set_uri("/foo", true)
		-- 
		-- rewrite ^ /foo break;
		-- 等价于
		-- ngx.req.set_uri("/foo", false)
		ngx.req.set_uri(url, false)
	else
		-- ngx.say(url)
		ngx.req.set_uri(url, false)
	end
end

-- 发送文本响应
function Response:send(text)
	self:set_header('Content-Type', 'text/plain; charset=UTF-8')
	self:_send(text)
end

-- 私有方法，用于实际发送响应内容
function Response:_send(content)
	ngx.status = self.http_status or 200
	ngx.say(content)
end

-- 获取响应体
function Response:get_body()
	return self.body
end

-- 获取响应头
function Response:get_headers()
	return self.headers
end

-- 获取响应体
function Response:get_header(key)
	return self.headers[key]
end

-- 设置响应体
function Response:set_body(body)
	if body ~= nil then self.body = body end
end

-- 设置状态码
function Response:status(status)
	ngx.status = status
	self.http_status = status
	return self
end

-- 设置响应头
function Response:set_header(key, value)
	ngx.header[key] = value
end

return Response
