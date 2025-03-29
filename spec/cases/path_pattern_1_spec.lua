-- Comment: 1.1路径匹配测试
--        : 1.2非严格匹配路径匹配测试
--        : 1.3路径不匹配测试
--        : 1.4同上

before_each(function()
	lor = _G.lor
	app = lor({
		debug = false
	})
	Request = _G.request
	Response = _G.response
	req = Request:new()
	res = Response:new()

	count = 0

	-- 这个并不是在root上增加中间件
	app:use("/", function(req, res, next)
		count = 1
		-- print(count)
		next()
	end)

	-- 这个并不是给/user增加中间件
	app:use("/user/", function(req, res, next)
		count = 2
		-- print(count)
		next()
	end)
	app:use("/user/:id/view", function(req, res, next)
		count = 3
		-- print(count)
		next()
	end)
	app:get("/user/123/view", function(req, res, next)
		count = 4
		-- print(count)
		next()
	end)

	app:post("/book" , function(req, res, next)
		count = 5
		next()
	end)

	-- 一个新的router，区别于主router
	local testRouter = lor:Router()
	testRouter:get("/get", function(req, res, next)
		count = 6
		next()
	end)
	testRouter:post("/foo/bar", function(req, res, next)
		count = 7
		next()
	end)
	app:use("/test", testRouter())

	app:erroruse(function(err, req, res, next)
		count = 999
		next()
	end)
end)

after_each(function()
	lor = nil
	app = nil
	Request = nil
	Response = nil
	req = nil
	res = nil
end)

describe("next function usages test", function()
	it("test case 1", function()
		req.path = "/user/123/view"
		req.method = "get"
		app:handle(req, res, function(err)
			assert.is_true(req:is_found())
		end)

		assert.is.equals(4, count)
		assert.is.equals(nil, req.params.id)
		-- _G.json_view(app.router.trie)
	end)

	-- route found
	it("test case 2", function()
		-- 设置为非严格匹配
		app:conf("strict_route", false)
		-- match app:get("/user/123/view", fn())
		req.path = "/user/123/view/"
		req.method = "get"
		app:handle(req, res, function(err)
			assert.is_true(req:is_found())
		end)

		assert.is.equals(4, count)
		assert.is.equals(nil, req.params.id)
	end)

	it("test case 3", function()
		req.path = "/book"
		req.method = "get"
		app:handle(req, res)

		assert.is.equals(999, count)
		assert.is_nil( req.params.id)

		req.method = "post" -- post match
		app:handle(req, res, function(err)
			assert.is_true(req:is_found())
		end)

		assert.is.equals(5, count)
		assert.is_nil( req.params.id)
	end)

	it("test case 4", function()
		req.path = "/notfound"
		req.method = "get"
		app:handle(req, res, function(err)
			assert.is_not_true(req:is_found())
			assert.is_nil(err)
		end)

		assert.is.equals(999, count)
		assert.is_nil(req.params.id)
	end)
end)
