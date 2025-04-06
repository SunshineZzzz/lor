-- Comment: jwt中间件

local ngx_log = ngx.log
local ngx_err = ngx.ERR
local jwt = require("lor.lib.utils.jwt")
local utils = require("lor.lib.utils.utils")
local http_unauthorized = ngx.HTTP_UNAUTHORIZED

local jwt_middleware = function(config)
	config = config or {}
	config.key = config.key or "lor"
	config.alg = config.alg or "HS256"
	config.acceptedIssuers = config.acceptedIssuers or nil
	config.acceptedAudiences = config.acceptedAudiences or nil
	config.exclude = config.exclude or {"^/login/", "^/api/"}
	config.notToken = config.notToken or {status = http_unauthorized, message = "未授权，请登录"}

	return function(req, res, next)
		local is_exclude = false
		for i=1, #config.exclude do
			if utils.is_match(req.uri, config.exclude[i]) then
				is_exclude = true
				break
			end
		end

		if is_exclude then
			next()
			return
		end

		local token = req.headers["Authorization"] or ""
		if token == "" then
			res:status(http_unauthorized):json(config.notToken)
			ngx_log(ngx_err, "jwt_middleware not token, uri:", req.uri)
			return
		end

		local payload, err = jwt.verify(token, config.key, config.alg, config.acceptedIssuers, config.acceptedAudiences)
		if err then
			res:status(http_unauthorized):json(config.notToken)
			ngx_log(ngx_err, "jwt_middleware verify token error, uri:", req.uri, ", err:", err)
			return
		end

		req.jwt = payload
		next()
	end
end

return jwt_middleware