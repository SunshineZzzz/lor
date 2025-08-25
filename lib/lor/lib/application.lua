-- Comment: web应用

local pairs = pairs
local type = type
local xpcall = xpcall
local setmetatable = setmetatable

local Router = require("lor.lib.router.router")
local Request = require("lor.lib.request")
local Response = require("lor.lib.response")
local View = require("lor.lib.view")
local supported_http_methods = require("lor.lib.methods")
local middleware_type = Router.get_middleware_type()

-- 是否需要传递给路由的配置
local router_conf = {
	-- 路由严格匹配模式
	strict_route = true,
	-- 路由大小写
	ignore_case = true,
	-- 最大路由字段
	max_uri_segments = true,
	-- 最大路由回退深度
	max_fallback_depth = true
}

-- web应用
local App = {}

-- 新建
function App:new()
	local instance = {}
	-- instance.cache = {}
	-- 配置项key<->value
	instance.settings = {}
	instance.router = Router:new()

	setmetatable(instance, {
		__index = self,
		__call = self.handle
	})

	instance:init_method()
	return instance
end

-- 运行处理流程
function App:run(final_handler)
	local request = Request:new()
	local response = Response:new()

	local enable_view = self:getconf("view enable")
	if enable_view then
		local view_config = {
			view_enable = enable_view,
			-- view engine: resty-template or others...
			view_engine = self:getconf("view engine"),
			-- defautl is "html"
			view_ext = self:getconf("view ext"),
			-- defautl is ""
			view_layout = self:getconf("view layout"),
			-- template files directory
			views = self:getconf("views")
		}

		local view = View:new(view_config)
		response.view = view
	end

	self:handle(request, response, final_handler)
end

-- 初始化
function App:init(options)
	self:default_configuration(options)
end

function App:default_configuration(options)
	options = options or {}

	-- view and template configuration
	if options["view enable"] ~= nil and options["view enable"] == true then
		self:conf("view enable", true)
	else
		self:conf("view enable", false)
	end
	self:conf("view engine", options["view engine"] or "tmpl")
	self:conf("view ext", options["view ext"] or "html")
	self:conf("view layout", options["view layout"] or "")
	self:conf("views", options["views"] or "./app/views/")

	self.locals = {}
	self.locals.settings = self.setttings
end

-- 分发请求
-- dispatch `req, res` into the pipeline.
function App:handle(req, res, callback)
	local router = self.router
	local done = callback or function(err)
		if err then
			if ngx then ngx.log(ngx.ERR, err) end
			res:status(500):send("internal error! please check log.")
		end
	end

	if not router then
		return done()
	end

	local err_msg
	local ok, _ = xpcall(function()
		router:handle(req, res, done)
	end, function(msg)
		err_msg = msg
	end)

	if not ok then
		done(err_msg)
	end
end

-- 添加中间件
function App:use(path, fn)
	self:inner_use(middleware_type.normal, path, fn)
end

-- 添加错误中间件
-- just a mirror for `erroruse`
function App:erruse(path, fn)
	self:erroruse(path, fn)
end
function App:erroruse(path, fn)
	self:inner_use(middleware_type.error, path, fn)
end

-- 注册中间件
-- should be private
function App:inner_use(fn_args_length, path, fn)
	local router = self.router

	if path and fn and type(path) == "string" then
		router:use(path, fn, fn_args_length)
	elseif path and not fn then
		fn = path
		path = nil
		router:use(path, fn, fn_args_length)
	else
		error("error usage for `middleware`")
	end

	return self
end

-- 支持的HTTP方法封装对应的添加路由规则函数
function App:init_method()
	for http_method, _ in pairs(supported_http_methods) do
		self[http_method] = function(_self, path, ...) -- funcs...
			_self.router:app_route(http_method, path, ...)
			return _self
		end
	end
end

-- 所有支持的HTTP方法都添加路由规则
function App:all(path, ...)
	for http_method, _ in pairs(supported_http_methods) do
		self.router:app_route(http_method, path, ...)
	end

	return self
end

-- 配置
function App:conf(setting, val)
	self.settings[setting] = val

	-- 允许的话需要传递给路由对象
	if router_conf[setting] == true then
		self.router:conf(setting, val)
	end

	return self
end

-- 获取配置
function App:getconf(setting)
	return self.settings[setting]
end

-- 启用指定的配置项
function App:enable(setting)
	self.settings[setting] = true
	return self
end

-- 禁用指定的配置项
function App:disable(setting)
	self.settings[setting] = false
	return self
end

-- 图示路由前缀树
--- only for dev
function App:gen_graph()
	return self.router.trie:gen_graph()
end

return App
