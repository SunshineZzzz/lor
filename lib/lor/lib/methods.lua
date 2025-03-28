-- Comment: 支持的HTTP方法

-- get and post methods is guaranteed, the others is still in process
-- but all these methods shoule work at most cases by default
local supported_http_methods = {
	-- work well
	get = true,
	-- work well
	post = true,
	-- no test
	head = true,
	-- no test
	options = true,
	-- work well
	put = true,
	-- no test
	patch = true,
	-- work well
	delete = true,
	-- no test
	trace = true,
	-- todo:
	all = true
}

return supported_http_methods