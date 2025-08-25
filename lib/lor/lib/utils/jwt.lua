-- Comment: 跨域认证，jwt实现，https://github.com/jitsi/jitsi-meet/blob/master/resources/prosody-plugins/luajwtjitsi.lib.lua

local os_time = os.time
local tostring = tostring
local type = type
local table_concat = table.concat
local table_remove = table.remove
local ipairs = ipairs
local cjson_safe = require("cjson.safe")
local digest = require("resty.openssl.digest")
local hmac = require("resty.openssl.hmac")
local pkey = require("resty.openssl.pkey")
local base64 = require("lor.lib.utils.base64")
local utils = require("lor.lib.utils.utils")

-- 用RSA私钥对数据进行签名
-- data:需要签名的字符串（通常是 header.payload）
-- key:RSA私钥
-- algo:哈希算法（sha256/sha384/sha512）
local function signRS(data, key, algo)
	local privkey = pkey.new(key)
	if privkey == nil then
		return nil, 'Not a private PEM key'
	end

	local datadigest = digest.new(algo):update(data)
	return privkey:sign(datadigest)
end

-- 用RSA公钥验证签名是否有效
-- data:原始数据（通常是 header.payload）
-- signature:需要验证的签名
-- key:RSA公钥
-- algo:哈希算法（sha256/sha384/sha512）
local function verifyRS(data, signature, key, algo)
	local pubkey = pkey.new(key)
	if pubkey == nil then
		return false
	end

	local datadigest = digest.new(algo):update(data)
	return pubkey:verify(signature, datadigest)
end

--  HMAC&RSA签名方法
local alg_sign = {
	-- 共享密钥计算签名
	['HS256'] = function(data, key) return hmac.new(key, 'sha256'):final(data) end,
	['HS384'] = function(data, key) return hmac.new(key, 'sha384'):final(data) end,
	['HS512'] = function(data, key) return hmac.new(key, 'sha512'):final(data) end,
	-- 私钥计算签名
	['RS256'] = function(data, key) return signRS(data, key, 'sha256') end,
	['RS384'] = function(data, key) return signRS(data, key, 'sha384') end,
	['RS512'] = function(data, key) return signRS(data, key, 'sha512') end
}

-- HMAC&RSA签名验证方法
local alg_verify = {
	-- 共享密钥验证签名
	['HS256'] = function(data, signature, key) return signature == alg_sign['HS256'](data, key) end,
	['HS384'] = function(data, signature, key) return signature == alg_sign['HS384'](data, key) end,
	['HS512'] = function(data, signature, key) return signature == alg_sign['HS512'](data, key) end,
	-- 公钥验证签名
	['RS256'] = function(data, signature, key) return verifyRS(data, signature, key, 'sha256') end,
	['RS384'] = function(data, signature, key) return verifyRS(data, signature, key, 'sha384') end,
	['RS512'] = function(data, signature, key) return verifyRS(data, signature, key, 'sha512') end
}

-- 把JWT字符串按.分割成header，payload，signature三部分
local function split_token(token)
	return utils.split(token, "\\.", ".")
end

-- 解析JWT，解码header，payload，signature
local function parse_token(token)
	local segments=split_token(token)
	if #segments ~= 3 then
		return nil, nil, nil, "Invalid token"
	end

	local header, err = cjson_safe.decode(base64.pure_decode(segments[1]))
	if err then
		return nil, nil, nil, "Invalid header"
	end

	local payload, err = cjson_safe.decode(base64.pure_decode(segments[2]))
	if err then
		return nil, nil, nil, "Invalid payload"
	end

	local sig, err = base64.pure_decode(segments[3])
	if err then
		return nil, nil, nil, "Invalid signature"
	end

	return header, payload, sig
end

-- 去除jwt的签名部分，返回 header.payload
local function strip_signature(token)
	local segments = split_token(token)
	if #segments ~= 3 then
		return nil, nil, nil, "Invalid token"
	end

	table_remove(segments)
	return table_concat(segments, ".")
end

-- jwt的payload，验证一个给定的声明是否符合一组可接受的声明 
local function verify_claim(claim, acceptedClaims)
	for i, accepted in ipairs(acceptedClaims) do
		if accepted == '*' then
			return true
		end
		if claim == accepted then
			return true
		end
	end

	return false
end

local M = {}

-- 创建jwt
function M.encode(data, key, alg, header)
	if type(data) ~= 'table' then 
		return nil, "Argument #1 must be table" 
	end

	if type(key) ~= 'string' then 
		return nil, "Argument #2 must be string" 
	end

	alg = alg or "HS256"

	if not alg_sign[alg] then
		return nil, "Algorithm not supported"
	end

	header = header or {}

	header['typ'] = 'JWT'
	header['alg'] = alg

	local headerEncoded, err = cjson_safe.encode(header)
	if headerEncoded == nil then
		return nil, err
	end

	local dataEncoded, err = cjson_safe.encode(data)
	if dataEncoded == nil then
		return nil, err
	end

	local segments = {
		base64.pure_encode(headerEncoded),
		base64.pure_encode(dataEncoded)
	}

	local signing_input = table_concat(segments, ".")
	local signature, error = alg_sign[alg](signing_input, key)
	if signature == nil then
		return nil, error
	end

	segments[#segments+1] = base64.pure_encode(signature)

	return table_concat(segments, ".")
end

-- 验证jwt是否有效
-- token:jwt字符串
-- key:用于验证的密钥（HMAC或公钥（RSA）
-- expectedAlgo:预期的签名算法，必须与header.alg匹配
-- acceptedIssuers:允许的发行者（iss）列表，不匹配则验证失败
-- acceptedAudiences:允许的受众（aud）列表，不匹配则验证失败
function M.verify(token, key, expectedAlgo, acceptedIssuers, acceptedAudiences)
	if type(token) ~= 'string' then 
		return nil, "token argument must be string" 
	end

	if type(key) ~= 'string' then 
		return nil, "key argument must be string" 
	end

	expectedAlgo = expectedAlgo or "HS256"
	if type(expectedAlgo) ~= 'string' then 
		return nil, "algorithm argument must be string" 
	end

	if acceptedIssuers ~= nil and type(acceptedIssuers) ~= 'table' then
		return nil, "acceptedIssuers argument must be table"
	end

	if acceptedAudiences ~= nil and type(acceptedAudiences) ~= 'table' then
		return nil, "acceptedAudiences argument must be table"
	end

	if not alg_verify[expectedAlgo] then
		return nil, "Algorithm not supported"
	end

	local header, payload, sig, err = parse_token(token)
	if err ~= nil then
		return nil, err
	end

	-- Validate header
	if not header.typ or header.typ ~= "JWT" then
		return nil, "Invalid typ"
	end

	if not header.alg or header.alg ~= expectedAlgo then
		return nil, "Invalid or incorrect alg"
	end

	-- Validate signature
	if not alg_verify[expectedAlgo](strip_signature(token), sig, key) then
		return nil, 'Invalid signature'
	end

	-- Validate payload
	if payload.exp and type(payload.exp) ~= "number" then
		return nil, "exp must be number"
	end

	if payload.nbf and type(payload.nbf) ~= "number" then
		return nil, "nbf must be number"
	end

	-- 过期了
	if payload.exp and os_time() >= payload.exp then
		local extra_msg = '';
		-- 签发时间
		if payload.iat then
			-- 令牌的有效期
			extra_msg = ", valid for:" .. tostring(payload.exp - payload.iat) .. " sec";
		end
		-- 已过期的秒数
		return nil, "Not acceptable by exp (" .. tostring(os_time() - payload.exp) .. " sec since expired" .. extra_msg ..")"
	end

	-- 生效时间，未生效
	if payload.nbf and os_time() < payload.nbf then
		return nil, "Not acceptable by nbf"
	end

	-- 验证令牌签发者是否可信
	if acceptedIssuers ~= nil then
		local issClaim = payload.iss;
		if issClaim == nil then
			return nil, "'iss' claim is missing";
		end

		if not verify_claim(issClaim, acceptedIssuers) then
			return nil, "invalid 'iss' claim";
		end
	end

	-- 验证令牌的目标受众是否正确
	if acceptedAudiences ~= nil then
		local audClaim = payload.aud;
		if audClaim == nil then
			return nil, "'aud' claim is missing";
		end

		if not verify_claim(audClaim, acceptedAudiences) then
			return nil, "invalid 'aud' claim";
		end
	end

	return payload
end

return M