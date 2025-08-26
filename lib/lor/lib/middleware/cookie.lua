-- Comment: 绑定cookie相关函数的中间件

local ck = require("resty.cookie")

-- Mind:
-- base on 'lua-resty-cookie', https://github.com/cloudflare/lua-resty-cookie
-- this is the default `cookie` middleware
-- you're recommended to define your own `cookie` middleware.

-- usage example:
--      app:get("/user", function(req, res, next)
--          local ok, err = req.cookie.set({
--              key = "qq",
--              value =  '4==||==hello zhang==||==123456',
--              path = "/",
--              domain = "new.cn",
--              secure = false, --设置后浏览器只有访问https才会把cookie带过来,否则浏览器请求时不带cookie参数
--              httponly = true, --设置后js 无法读取
--              --expires =  ngx.cookie_time(os.time() + 3600),
--              max_age = 3600, --用秒来设置cookie的生存期。
--              samesite = "Strict",  --或者 Lax 指a域名下收到的cookie 不能通过b域名的表单带过来
--              extension = "a4334aebaece"
--          })
--      end)

local cookie_middleware = function()
	return function(req, res, next)
		local COOKIE, err = ck:new()

		if not COOKIE then
			ngx.log(ngx.ERR, "cookie_middleware ck:new error:", err)

			req.cookie = {} -- all cookies
			res._cookie = nil
		else
			req.cookie = {
				set = function(...)
					local _cookie = COOKIE
					if not _cookie then
						return false, "cookie_middleware _cookie not found"
					end

					local p = ...
					if type(p) == "table" then
						local ok, err = _cookie:set(p)
						if not ok then
							return false, err
						end
					else
						local params = { ... }
						local ok, err = _cookie:set({
							key = params[1],
							value = params[2] or "",
						})
						if not ok then
							return false, err
						end
					end

					return true, nil
				end,

				get = function (name)
					local _cookie = COOKIE
					if not _cookie then
						return nil, "cookie_middleware _cookie not found"
					end

					local field, err = _cookie:get(name)

					if not field then
						return nil, err
					end

					return field, nil
				end,

				get_all = function ()
					local _cookie = COOKIE
					if not _cookie then
						return false, "cookie_middleware _cookie not found"
					end

					local fields, err = _cookie:get_all()

					local t = {}
					if not fields then
						return nil, err
					else
						for k, v in pairs(fields) do
							if k and v then
								t[k] = v
							end
						end
						return t, nil
					end
				end
			}
		end

		next()
	end
end

return cookie_middleware
