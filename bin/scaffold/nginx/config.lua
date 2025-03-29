-- Comment: 构建Nginx配置

local pairs = pairs
local ogetenv = os.getenv
local utils = require 'bin.scaffold.utils'
local app_run_env = ogetenv("LOR_ENV") or 'dev'

local lor_ngx_conf = {}

lor_ngx_conf.common = { 
	-- directives
	-- 运行环境
	LOR_ENV = app_run_env,
	-- INIT_BY_LUA_FILE = './app/nginx/init.lua',
	-- LUA_PACKAGE_PATH = '',
	-- LUA_PACKAGE_CPATH = '',
	-- 执行的Lua脚本文件的路径
	CONTENT_BY_LUA_FILE = './app/main.lua',
	-- 静态文件路径
	STATIC_FILE_DIRECTORY = './app/static'
}

lor_ngx_conf.env = {}
-- 开发环境配置
lor_ngx_conf.env.dev = {
	LUA_CODE_CACHE = false,
	PORT = 8888
}

-- 测试环境配置
lor_ngx_conf.env.test = {
	LUA_CODE_CACHE = true,
	PORT = 9999
}

-- 生产环境配置
lor_ngx_conf.env.prod = {
	LUA_CODE_CACHE = true,
	PORT = 80
}

-- 返回合并后的配置
local function getNgxConf(conf_arr)
	if conf_arr['common'] ~= nil then
		local common_conf = conf_arr['common']
		local env_conf = conf_arr['env'][app_run_env]
		for directive, info in pairs(common_conf) do
			env_conf[directive] = info
		end
		return env_conf
	elseif conf_arr['env'] ~= nil then
		return conf_arr['env'][app_run_env]
	end
	return {}
end

-- 生成当前环境Nginx配置
local function buildConf()
	local sys_ngx_conf = getNgxConf(lor_ngx_conf)
	return sys_ngx_conf
end

-- 拿到Nginx配置指令生成器对象
local ngx_directive_handle = require('bin.scaffold.nginx.directive'):new(app_run_env)
-- 拿到Nginx配置指令生成器
local ngx_directives = ngx_directive_handle:directiveSets()
-- 生成当前环境Nginx配置
local ngx_run_conf = buildConf()

-- 最终生成Nginx配置
local LorNgxConf = {}
for directive, func in pairs(ngx_directives) do
	if type(func) == 'function' then
		local func_rs = func(ngx_directive_handle, ngx_run_conf[directive])
		if func_rs ~= false then
			LorNgxConf[directive] = func_rs
		end
	else
		LorNgxConf[directive] = ngx_run_conf[directive]
	end
end

return LorNgxConf
