-- Comment: 初始化中间件

local init_middleware = function(req, res, next)
	req.res = res
	req.next = next
	res.req = req
	res:set_header('X-Powered-By', 'lor Web Framework')
	res.locals = res.locals or {}
	next()
end

return init_middleware
