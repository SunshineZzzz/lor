-- Comment: 测试中间件或者错误中间件是否正常运行

-- ​before_each在每次子测试(it块)之前运行
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

-- after_each在每次子测试(it块)之后运行
after_each(function()
	lor = nil
	app = nil
	Request = nil
	Response = nil
	req = nil
	res = nil
end)

describe("basic test for common usages", function()
	it("use middleware should works.", function()
		local count = 1
		app:use("/user", function(req, res, next)
			count = count + 1
			next()
		end)

		-- 不进入这里
		app:use("/user/123", function(req, res, next)
			count = count + 1
			next()
		end)

		app:get("/user/:id/create", function(req, res, next)
			count = count + 1
		end)

		req.path ="/user/123/create"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(count, 3)

		-- _G.json_view(app.router.trie)
	end)

	it("error middleware should work.", function()
		local origin_error_msg, error_msg = "this is an error", ""
		app:use("/user", function(req, res, next)
			next()
		end)

		app:get("/user/123/create", function(req, res, next)
			-- let other handlers continue...
			next(origin_error_msg)
		end)

		app:erroruse(function(err, req, res, next)
			error_msg = err
		end)

		req.path = "/user/123/create"
		req.method = "get"
		app:handle(req, res)
		assert.is.equals(error_msg, origin_error_msg)
	end)
end)
