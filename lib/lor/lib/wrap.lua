-- Copyright (C) Pixel Studio
-- All rights reserved.
-- 
-- Author : YangZhang
-- Date   : 06/09/2024
-- Comment: 创建和管理Web应用程序

local setmetatable = setmetatable

local _M = {}

function _M:new(create_app, Router, Group, Request, Response)
	local instance = {}
	instance.router = Router
	instance.group = Group
	instance.request = Request
	instance.response = Response
	instance.fn = create_app
	instance.app = nil

	setmetatable(instance, {
		__index = self,
		__call = self.create_app
	})

	return instance
end

-- 创建web应用
-- Generally, this should only be used by `xxmini` framework itself.
function _M:create_app(options)
	self.app = self.fn(options)
	return self.app
end

-- 创建新的路由器
function _M:Router(options)
	return self.group:new(options)
end

-- 创建新的请求对象
function _M:Request()
	return self.request:new()
end

-- 创建新的回执对象
function _M:Response()
	return self.response:new()
end

-- 创建新的路由组
function _M:Group()
	return self.group:new()
end

return _M
