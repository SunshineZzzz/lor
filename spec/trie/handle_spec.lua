-- Comment: 挂载handle测试

setup(function()
	local optDebug = require("lor.debug")
	optDebug.set_debug(true)
	_debug = require("lor.lib.debug")
end)

teardown(function()
end)

before_each(function()
	Trie = _G.Trie
	t = Trie:new()
	t1 = Trie:new()
	t2 = Trie:new()
end)

after_each(function()
	Trie = nil
	t = nil
	t1 = nil
	t2 = nil
	_debug = nil
end)

describe("`handler` test cases: ", function()
	it("should succeed to define handlers.", function()
		local n1 = t:add_node("/a")
		local m1 = t:add_node("/a/b")
		local m2 = t:add_node("/a/c")
		local m3 = t:add_node("/a/:name")

		n1:handle("get", function(req, res, next) end)
		assert.is.equals(1, #n1.handlers["get"])

		n1:handle("post", function(req, res, next) end)
		assert.is.equals(1, #n1.handlers["post"])

		n1:handle("put", function(req, res, next) end, function(req, res, next) end, function(req, res, next) end)
		assert.is.equals(3, #n1.handlers["put"])

		n1:handle("DELETE", {function(req, res, next) end, function(req, res, next) end})
		assert.is.equals(2, #n1.handlers["delete"])

		m2:handle("get", function(req, res, next) end)
		assert.is.equals(1, #m2.handlers["get"])
	end)

	it("should failed to define handlers.", function()
		local n1 = t:add_node("/a")

		assert.has_error(function()
			-- wrong `method` name
			n1:handle("getabc", function(req, res, next) end)
		end)

		assert.has_error(function()
			n1:handle("get", {})
		end)

		assert.has_error(function()
			n1:handle("get", function(req, res, next) end)
			-- define handler repeatly
			n1:handle("get", function(req, res, next) end)
		end)

		--_debug(n1)
		--json_view(t)
		--print(t:gen_graph())
	end)
end)

