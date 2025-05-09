-- Comment: 安全回话数据中间件

local type, xpcall = type, xpcall
local traceback = debug.traceback
local string_sub = string.sub
local string_len = string.len
local http_time = ngx.http_time
local ngx_time = ngx.time
local ck = require("resty.cookie")
local utils = require("lor.lib.utils.utils")
local aes = require("lor.lib.utils.aes")
local base64 = require("lor.lib.utils.base64")

-- 字段解密
local function decode_data(field, aes_key, ase_secret)
	if not field or field == "" then return {} end
	local payload = base64.decode(field)
	local data = {}
	local cipher = aes.new()
	local decrypt_str = cipher:decrypt(payload, aes_key, ase_secret)
	local decode_obj = utils.json_decode(decrypt_str)
	return decode_obj or data
end

-- 字段加密
local function encode_data(obj, aes_key, ase_secret)
	local default = "{}"
	local str = utils.json_encode(obj) or default
	local cipher = aes.new()
	local encrypt_str = cipher:encrypt(str, aes_key, ase_secret)
	local encode_encrypt_str = base64.encode(encrypt_str)
	return encode_encrypt_str
end

-- 解析session
local function parse_session(field, aes_key, ase_secret)
	if not field then return end
	return decode_data(field, aes_key, ase_secret)
end

--- no much secure & performance consideration
--- TODO: optimization & security issues
local session_middleware = function(config)
	config = config or {}
	config.session_key = config.session_key or "_app_"
	if config.refresh_cookie ~= false then
		config.refresh_cookie = true
	end
	if not config.timeout or type(config.timeout) ~= "number" then
		-- default session timeout is 3600 seconds
		config.timeout = 3600
	end
	
	local err_tip = "session_aes_key should be set for session middleware"
	-- backward compatibility for lor < v0.3.2
	config.session_aes_key = config.session_aes_key or "custom_session_aes_key"
	if not config.session_aes_key then
		ngx.log(ngx.ERR, err_tip)
	end

	-- session关键字
	local session_key = config.session_key
	-- 秘钥
	local session_aes_key = config.session_aes_key
	local refresh_cookie = config.refresh_cookie
	local timeout = config.timeout
	-- 秘钥盐
	-- session_aes_secret must be 8 charactors to respect lua-resty-string v0.10+
	local session_aes_secret = config.session_aes_secret or config.secret or "12345678"
	if string_len(session_aes_secret) < 8 then
		for i=1,8-string_len(session_aes_secret),1 do
			session_aes_secret = session_aes_secret .. "0"
		end
	end
	session_aes_secret = string_sub(session_aes_secret, 1, 8)

	ngx.log(ngx.INFO, "session middleware initialized")
	return function(req, res, next)
		if not session_aes_key then
			return next(err_tip)
		end

		local cookie, err = ck:new()
		if not cookie then
			ngx.log(ngx.ERR, "cookie is nil:", err)
		end

		local current_session
		local session_data, err = cookie:get(session_key)
		if err then
			ngx.log(ngx.ERR, "cannot get session_data:", err)
		else
			if session_data then
				current_session = parse_session(session_data, session_aes_key, session_aes_secret)
			end
		end
		current_session = current_session or {}

		req.session = {
			-- 给会话设置新的值，这些值将被加密存储在cookie中
			set = function(...)
				local p = ...
				if type(p) == "table" then
					for i, v in pairs(p) do
						current_session[i] = v
					end
				else
					local params = { ... }
					if type(params[2]) == "table" then
						-- set("k", {1, 2, 3})
						current_session[params[1]] = params[2]
					else 
						-- set("k", "123")
						current_session[params[1]] = params[2] or ""
					end
				end

				local value = encode_data(current_session, session_aes_key, session_aes_secret)
				local expires = http_time(ngx_time() + timeout)
				local max_age = timeout
				local ok, err = cookie:set({
					key = session_key,
					value = value or "",
					expires = expires,
					max_age = max_age,
					path = "/"
				})

				ngx.log(ngx.INFO, "session.set: ", value)

				if err or not ok then
					return ngx.log(ngx.ERR, "session.set error:", err)
				end
			end,
			-- 刷新会话，即延长会话的有效期
			refresh = function() 
				if session_data and session_data ~= "" then
					local expires = http_time(ngx_time() + timeout)
					local max_age = timeout
					local ok, err = cookie:set({
						key = session_key,
						value = session_data or "",
						expires = expires,
						max_age = max_age,
						path = "/"
					})
					if err or not ok then
						return ngx.log(ngx.ERR, "session.refresh error:", err)
					end
				end
			end,
			-- 获取会话中存储的值
			get = function(key)
				return current_session[key]
			end,
			-- 销毁会话，包括在 cookie 中删除会话数据
			destroy = function()
				local expires = "Thu, 01 Jan 1970 00:00:01 GMT"
				local max_age = 0
				local ok, err = cookie:set({
					key = session_key,
					value = "",
					expires = expires,
					max_age = max_age,
					path = "/"
				})
				if err or not ok then
					ngx.log(ngx.ERR, "session.destroy error:", err)
					return false
				end

				return true
			end
		}

		if refresh_cookie then
			local e, ok
			ok = xpcall(function() 
				req.session.refresh()
			end, function()
				e = traceback()
			end)

			if not ok then
				ngx.log(ngx.ERR, "refresh cookie error:", e)
			end
		end

		next()
	end
end

return session_middleware
