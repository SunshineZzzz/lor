-- Comment: 简单password加密
--        : todo bcrypt

local resty_sha512 = require "resty.sha512"
local resty_random = require "resty.random"
local str = require "resty.string"
local table_concat = table.concat
local utils = require("lor.lib.utils.utils")

local _M = {}

-- 默认配置
local DEFAULT_ITERATIONS = 2
local DEFAULT_SALT_LEN = 16

-- 生成加密强度的随机盐
function _M.generate_salt(len)
	len = len or DEFAULT_SALT_LEN
	local salt = resty_random.bytes(len)
	return str.to_hex(salt)
end

-- 内部哈希函数
local function _hash_data(data)
	local sha = resty_sha512:new()
	sha:update(data)
	return str.to_hex(sha:final())
end

-- 创建密码哈希
function _M.hash_password(password, salt, iterations)
	local salt = salt or _M.generate_salt(DEFAULT_SALT_LEN)
	local iterations = iterations or DEFAULT_ITERATIONS
		
	local hash = _hash_data(salt .. password)

	-- 迭代哈希
	for _ = 1, iterations - 1 do
		hash = _hash_data(hash .. salt .. password)
	end
	
	-- 返回格式: iterations$salt$hash
	return table_concat({
		iterations,
		salt,
		hash
	}, "$")
end

-- 验证密码
function _M.verify_password(password, hashed_password)
	if not password or not hashed_password then
		return false, "missing arguments"
	end
	
	-- 解析存储的哈希
	local parts = utils.split(hashed_password, "\\$", "$")
	if not parts or #parts ~= 3 then
		return false, "invalid password format"
	end
	
	local iterations = tonumber(parts[1])
	local salt = parts[2]
	
	-- 使用相同参数重新计算哈希
	local computed_hash, err = _M.hash_password(password, salt, iterations)
	
	if not computed_hash then
		return false, "hash computation failed: " .. err
	end
	
	-- 比较哈希值
	return computed_hash == hashed_password, nil
end

return _M