-- Comment: mysql封装

local setmetatable = setmetatable
-- local rawget = rawget
local type = type
local ipairs = ipairs
local table_insert = table.insert
local ngx_quote_sql_str = ngx.quote_sql_str
local resty_mysql = require("resty.mysql")
local utils = require("lor.lib.utils.utils")

local _M = {}

-- 默认配置
local defaults = {
	-- 地址
	host = "127.0.0.1",
	-- 端口
	port = 3306,
	-- 数据库
	database = "",
	-- 用户
	user = "",
	-- 密码
	password = "",
	-- 连接用的字符集
	charset = "utf8",
	-- 回复数据最大包大小
	max_packet_size = 1024 * 1024,
	-- 空闲连接保活时间，单位s
	keepalive = 10,
	-- 空闲池子大小
	pool = 100,
	-- mysql操作超时超时
	timeout = 3000,
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

	if not conf.database or type(conf.database) ~= "string" then
		return "database must be a string"
	end

	if not conf.user or type(conf.user) ~= "string" then
		return "user must be a string"
	end

	if not conf.password or type(conf.password) ~= "string" then
		return "password must be a string"
	end

	if not conf.charset or type(conf.charset) ~= "string" then
		return "charset must be a string"
	end

	if not conf.max_packet_size or type(conf.max_packet_size) ~= "number" then
		return "max_packet_size must be a number"
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

-- 构建sql
local function compose_sql(sqlTab, sqlParamTab)
	if sqlTab == nil or sqlParamTab == nil or 
	 not utils.table_is_array(sqlTab) or 
	 not utils.table_is_array(sqlParamTab) or 
	 #sqlTab ~= (#sqlParamTab+1) then
		return nil, "build sql error"
	end

	local sql = sqlTab[1]
	for i=1, #sqlParamTab do
		sql = sql .. sqlParamTab[i] .. sqlTab[i+1]
	end
	return sql, nil
end

-- 解析sql
local function parse_sql(sql, ...)
	local params = {...}
	if not params or #params == 0 then
		return sql, nil
	end

	local newParams = utils.new_table(0, #params)
	for _, v in ipairs(params) do
		if v and type(v) == "table" then
			return nil, "parse sql error"
		end
		if v and type(v) == "string" then
			v = ngx_quote_sql_str(v)
		end
		table_insert(newParams, v)
	end

	local t = utils.split(sql, "\\?", "?")
	return compose_sql(t, newParams)
end

-- 连接
function _M._connect(self, mysql)
	mysql:set_timeout(self.timeout)

	return mysql:connect({
		host = self.host,
		port = self.port,
		database = self.database,
		user = self.user,
		password = self.password,
		charset = self.charset,
		max_packet_size = self.max_packet_size
	})
end

-- 放入池子
function _M._set_keepalive(self, mysql)
	return mysql:set_keepalive(self.pool, self.keepalive)
end

-- 执行
function _M._exec(self, sql, out_mysql)
	local mysql
	if not out_mysql then
		local err
		mysql, err = resty_mysql:new()
		if not mysql then
			return nil, err
		end

		local ok, err = self:_connect(mysql)
		if not ok then
			return nil, err
		end
	else
		mysql = out_mysql
	end

	local res, err = mysql:query(sql)
	if not res then
		mysql:close()
		return nil, err
	end

	local ress = {}
	table_insert(ress, res)

	while err == "again" do
		res, err = mysql:read_result()
		if not res then
			mysql:close()
			return nil, err
		end

		table_insert(ress, res)
	end

	if not out_mysql then
		local ok, _ = self:_set_keepalive(mysql)
		if not ok then
			mysql:close()
		end
	end

	return ress, nil
end

-- 查询
function _M._query(self, out_mysql, sql, ...)
	local err
	sql, err = parse_sql(sql, ...)
	if not sql then
		return nil, err
	end
	return self:_exec(sql, out_mysql)
end

-- select
function _M.select(self, sql, ...)
	return self:_query(nil, sql, ...)
end

-- insert
function _M.insert(self, sql, ...)
	return self:_query(nil, sql, ...)
end

-- update
function _M.update(self, sql, ...)
	return self:_query(nil, sql, ...)
end

-- delete
function _M.delete(self, sql, ...)
	return self:_query(nil, sql, ...)
end

-- 开始事务
function _M.begin(self)
	local mysql, err = resty_mysql:new()
	if not mysql then
		return nil, err
	end

	local ok
	ok, err = self:_connect(mysql)
	if not ok then
		return nil, err
	end

	local res
	res, err = mysql:query("BEGIN")
	if not res then
		mysql:close()
		return nil, err
	end

	return mysql, nil
end

-- 提交事务
function _M.commit(self, mysql)
	if not mysql then
		return false, "no active transaction"
	end

	local res, err = mysql:query("COMMIT;SET autocommit=1")
	if not res then
		mysql:close()
		return false, err
	end

	local ok
	ok, err = self:_set_keepalive(mysql)
	if not ok then
		mysql:close()
	end

	return true, nil
end

-- 回滚事务
function _M.rollback(self, mysql)
	if not mysql then
		return false, "no active transaction"
	end

	local res, err = mysql:query("ROLLBACK")
	if not res then
		mysql:close()
		return false, err
	end

	local ok
	ok, err = self:_set_keepalive(mysql)
	if not ok then
		mysql:close()
	end

	return true, nil
end

-- select
function _M.tx_select(self, out_mysql, sql, ...)
	return self:_query(out_mysql, sql, ...)
end

-- insert
function _M.tx_insert(self, out_mysql, sql, ...)
	return self:_query(out_mysql, sql, ...)
end

-- update
function _M.tx_update(self, out_mysql, sql, ...)
	return self:_query(out_mysql, sql, ...)
end

-- delete
function _M.tx_delete(self, out_mysql, sql, ...)
	return self:_query(out_mysql, sql, ...)
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
		database = conf.database or defaults.database,
		user = conf.user or defaults.user,
		password = conf.password or defaults.password,
		charset = conf.charset or defaults.charset,
		max_packet_size = conf.max_packet_size or defaults.max_packet_size,
		keepalive = conf.keepalive or default.keepalive,
		pool = conf.pool or default.pool,
	}
	return setmetatable(instance, {__index = self}), nil
end

return _M