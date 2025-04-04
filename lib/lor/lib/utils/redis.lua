-- Comment: redis封装

local setmetatable = setmetatable
local rawget = rawget
local type = type
local unpack = unpack
local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local ngx_null = ngx.null
local resty_redis = require("resty.redis")
local utils = require("lor.lib.utils.utils")

-- 默认配置
local defaults = {
	-- 地址
	host = "127.0.0.1",
	-- 端口
	port = 6379,
	-- 数据库下标
	index = 0,
	-- 密码
	password = "",
	-- 空闲连接保活时间，单位ms
	keepalive = 60000,
	-- 空闲池子大小
	pool = 100,
	-- redis调用超时
	timeout = 3000
}

-- 检查配置
local function check_conf(conf)
	if not conf or type(conf) ~= "table" then
		return "conf must be a table"
	end

	if not conf.host or type(conf.host) ~= "string" then
		return "host must be a string"
	end

	if not conf.port or type(conf.port) ~= "number" then
		return "port must be a number"
	end

	if not conf.index or type(conf.index) ~= "number" then
		return "index must be a number"
	end

	if not conf.password or type(conf.password) ~= "string" then
		return "password must be a string"
	end

	if not conf.keepalive or type(conf.keepalive) ~= "number" then
		return "keepalive must be a number"
	end

	if not conf.pool or type(conf.pool) ~= "number" then
		return "pool must be a number"
	end

	if not conf.timeout or type(conf.timeout) ~= "number" then
		return "timeout must be a number"
	end

	return nil
end

-- 只要是ngx_null就返回true
local function is_redis_null(res)
	if type(res) == "table" then
		for k,v in pairs(res) do
			if v ~= ngx_null then
				return false
			end
		end
		return true
	elseif res == ngx_null then
		return true
	elseif res == nil then
		return true
	end
	return false
end

-- 执行redis cmd
local function do_command(self, cmd, ... )
	local _reqs = rawget(self, "_reqs")
	if _reqs then
		table_insert(self._reqs, {cmd, ...})
		return
	end

	local redis, err = resty_redis:new()
	if not redis then
		return nil, err
	end

	local ok, err = self:_connect(redis)
	if not ok then
		redis:close()
		return nil, err
	end

	local fun = redis[cmd]
	local result, err = fun(redis, ...)
	if not result then
		redis:close()
		return nil, err
	end

	if is_redis_null(result) then
		result = nil
	end
	
	ok, err = self._set_keepalive(redis)
	if not ok then
		redis:close()
	end

	return result, err
end

local _M = utils.new_table(0, 54)
_M._VERSION = '0.0'
setmetatable(_M, {__index = function(self, cmd)
	local method = function(self, ...)
		return do_command(self, cmd, ...)
	end
	_M[cmd] = method
	return method
end})

-- 连接
function _M._connect(self, redis)    
	redis:set_timeouts(self.timeout, self.timeout, self.timeout)
	
	local ok, err = redis:connect(self.host, self.port)
	if not ok then
		return nil, err
	end

	if self.password then
		local times, err = redis:get_reused_times()
		if err then
			return nil, err
		end

		local ok, err = redis:auth(self.password)
		if not ok then
			return nil, err
		end
	end

	if self.index ~= 0 then
		local ok, err = redis:select(db_index)
		if not ok then
			return nil, err
		end
	end

	return redis, nil
end

-- 放入池子
function _M._set_keepalive(self, redis)
	return redis:set_keepalive(self.keepalive, self.pool)
end

-- 初始化pipiline
function _M.init_pipeline(self, n)
	self._reqs = utils.new_table(n or 3, 0)
end

-- 取消pipiline
function _M.cancel_pipeline(self)
	self._reqs = nil
end

-- 提交pipiline
function _M.commit_pipeline(self)
	local _reqs = rawget(self, "_reqs") 
	self._reqs = nil

	if nil == _reqs or 0 == #_reqs then
		return nil, "no pipeline"
	end

	local redis, err = resty_redis:new()
	if not redis then
		return nil, err
	end

	local ok, err = self:_connect(redis)
	if not ok then
		redis:close()
		return nil, err
	end

	redis:init_pipeline()
	for _, vals in ipairs(_reqs) do
		local fun = redis[vals[1]]
		table_remove(vals, 1)
		fun(redis, unpack(vals))
	end

	local results, err = redis:commit_pipeline()
	if not results then
		redis:close()
		return nil, err
	end

	if is_redis_null(results) then
		results = {}
	end
	
	ok, err = self._set_keepalive(self, redis)
	if not ok then
		redis:close()
	end

	for i, value in ipairs(results) do
		if is_redis_null(value) then
			results[i] = nil
		end
	end

	return results, nil
end

-- 订阅
function _M.subscribe(self, channel)
	local redis, err = resty_redis:new()
	if not redis then
		return nil, err
	end

	local ok, err = self:_connect(redis)
	if not ok then
		redis:close()
		return nil, err
	end

	local res, err = redis:subscribe(channel)
	if not res then
		redis:close()
		return nil, err
	end

	local function do_read_func(do_read)
		if do_read == nil or do_read == true then
			res, err = redis:read_reply()
			if not res then
				redis:close()
				return nil, err
			end
			return res, nil
		end
	  
		redis:unsubscribe(channel)
		local ok, err = self._set_keepalive(self, redis)
		if not ok then
			redis:close()
		end
		return
	end

	return do_read_func
end

-- 创建
function _M.new(self, config)
	local conf = config or defaults
	local err = check_conf(conf)
	if err then
		return nil, err
	end

	local instance = {
		host = conf.host or defaults.host,
		port = conf.port or defaults.port,
		index = conf.index or defaults.index,
		password = conf.password or defaults.password,
		keepalive = conf.keepalive or default.keepalive,
		pool = conf.pool or default.pool,
		timeout = conf.timeout or default.timeout,
		_reqs = nil
	}
	return setmetatable(instance, {__index = _M}), nil
end

return _M