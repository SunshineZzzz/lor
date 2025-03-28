-- Comment: 路由严格匹配模式测试

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

describe("strict route: ", function()
	it("should match if strict route is false.", function()
		local t = Trie:new({
			-- default value is true
			strict_route = false
		})
		local n1 = t:add_node("/a/b")

		local m1 = t:match("/a/b/")
		assert.are.same(n1, m1.node)

		local m2 = t:match("/a/b")
		assert.are.same(n1, m2.node)
	end)

	it("should not match if strict route is true.", function()
		local t = Trie:new({
			-- default value is true
			strict_route = true
		})
		local n1 = t:add_node("/a/b")

		local m1 = t:match("/a/b")
		assert.are.same(n1, m1.node)

		local m2 = t:match("/a/b/")
		assert.is.falsy(m2.node)
	end)

	it("should match if strict route is false and the exact route is not given.", function()
		local t = Trie:new({
			-- default value is true
			strict_route = false
		})
		local n1 = t:add_node("/a/b")

		local m1 = t:match("/a/b/")
		assert.are.same(n1, m1.node)
	end)

	it("should not match if strict route is true and the exact route is not given.", function()
		local t = Trie:new({
			-- default value is true
			strict_route = true
		})
		local n1 = t:add_node("/a/b")

		local m1 = t:match("/a/b/")
		assert.is.falsy(m1.node)
		assert.is.equals(nil, m1.node)
	end)
end)