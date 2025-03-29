-- Comment: 1.1应用注册多个函数，数组形式传递
--        : 1.2应用注册多个函数，多个参数形式
--        : 2.1路由组注册多个函数，数组形式传递
--        : 2.2路由组注册多个函数，多个参数形式
--        : 3.1路由组注册多个函数，参数，数组混合形式
--        : 3.2路由组注册多个函数，参数，数组混合形式
--        : 4.1应用注册多个函数，参数，数组混合形式
--        : 4.2应用注册多个函数，参数，数组混合形式

before_each(function()
	lor = _G.lor
	app = lor({
		debug = true
	})
	Request = _G.request
	Response = _G.response
	req = Request:new()
	res = Response:new()
end)

after_each(function()
	lor = nil
	app = nil
	Request = nil
	Response = nil
	req = nil
	res = nil
end)


describe("multi route: mounted on `app`", function()
	it("array param", function()
		local flag = 0
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = req.query.flag or 3
		end
		app:get("/flag", {func1, func2, last_func})

		app:erroruse(function(err, req, res, next)
			-- should not reach here.
			assert.is.truthy(err)
			flag = 999
		end)

		req.path = "/flag"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)

		req.path = "/flag"
		req.query = {flag = 111}
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(111, flag)
	end)

	it("unpacked params", function()
		local flag = 0
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = req.query.flag or 3
		end
		app:get("/flag", func1, func2, last_func)

		app:erroruse(function(err, req, res, next)
			-- should not reach here.
			assert.is.truthy(err)
			flag = 999
		end)

		req.path = "/flag"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)

		req.path = "/flag"
		req.query = {flag = 111}
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(111, flag)
	end)
end)

describe("multi route: mounted on `group router`", function()
	it("array param", function()
		local flag = 0

		local test_router = lor:Router()
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = req.query.flag or 3
		end
		test_router:get("/flag", {func1, func2, last_func})

		app:use("/test", test_router())
		app:erroruse(function(err, req, res, next)
			-- should not reach here.
			assert.is.truthy(err)
			flag = 999
		end)

		req.path = "/test/flag"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)

		req.path = "/test/flag"
		req.query = {flag = 111}
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(111, flag)
	end)

	it("unpacked params", function()
		local flag = 0

		local test_router = lor:Router()
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = req.query.flag or 3
		end
		test_router:get("/flag", func1, func2, last_func)

		app:use("/test", test_router())
		app:erroruse(function(err, req, res, next)
			-- should not reach here.
			assert.is.truthy(err)
			flag = 999
		end)

		req.path = "/test/flag"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)

		req.path = "/test/flag"
		req.query = {flag = 111}
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(111, flag)
	end)
end)

describe("multi route: muixed funcs for group router", function()
	it("mixed params, case1", function()
		local flag = 0
		local test_router = lor:Router()
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = 3
		end
		test_router:put("mixed", {func1, func2}, last_func)
		app:use("/test", test_router())

		req.path = "/test/mixed"
		req.method = "put"
		app:handle(req, res)
		assert.is.equals(3, flag)
	end)

	it("mixed params, case2", function()
		local flag = 0
		local test_router = lor:Router()
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = 3
		end
		test_router:get("mixed", {func1}, func2, {last_func})
		app:use("/test", test_router())

		req.path = "/test/mixed"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)
	end)
end)

describe("multi route: muixed funcs for `app`", function()
	it("mixed params, case1", function()
		local flag = 0
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local last_func = function(req, res, next)
			flag = 3
		end
		app:get("mixed", {func1, func2}, last_func)

		req.path = "/mixed"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(3, flag)
	end)

	it("mixed params, case2", function()
		local flag = 0
		local func1 = function(req, res, next)
			flag = 1
			next()
		end
		local func2 = function(req, res, next)
			flag = 2
			next()
		end
		local func3 = function(req, res, next)
			flag = 3
			next()
		end
		local last_func = function(req, res, next)
			flag = 4
		end
		app:get("mixed", {func1}, func2, {func3}, last_func)

		req.path = "/mixed"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(4, flag)
	end)
end)
