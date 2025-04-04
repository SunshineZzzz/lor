-- Comment: base64编解码

local ngx       = ngx
local base64enc = ngx.encode_base64
local base64dec = ngx.decode_base64
local sgsub 	= ngx.re.gsub

local ENCODE_CHARS = {
	["+"] = "-",
	["/"] = "_",
	["="] = "."
}

local DECODE_CHARS = {
	["-"] = "+",
	["_"] = "/",
	["."] = "="
}

local base64 = {}

-- 纯编码
function base64.pure_encode(value)
	return base64enc(value)
end

-- 纯解码
function base64.pure_decode(value)
	return base64dec(value)
end

-- 编码
function base64.encode(value)
	local re, _ = sgsub(base64enc(value), "[+/=]", function(m) return ENCODE_CHARS[m[0]] end, "jo")
	return re
end

-- 解码
function base64.decode(value)
	local re, _ = sgsub(value, "[-_.]", function(m) return DECODE_CHARS[m[0]] end)
	return base64dec(re)
end

return base64
