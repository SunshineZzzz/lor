-- Comment: 基础测试函数暴露出来

expose("expose modules", function()
	package.path = '../../lib/?.lua;' .. '../../?.lua;'.. './lib/?.lua;'  .. package.path
	_G.Trie = require("lor.lib.trie")
	_G.Node = require("lor.lib.node")

	_G.json_view = function(t)
		local cjson
		pcall(function() cjson = require("cjson") end)
		if not cjson then
			print("\n[cjson should be installed...]\n")
		else
			if t.root then
				t:remove_nested_property(t.root)
				print("\n", cjson.encode(t.root), "\n")
			else
				t:remove_nested_property(t)
				print("\n", cjson.encode(t), "\n")
			end
		end
	end

	_G._debug = nil
	pcall(function() _G._debug = require("lor.lib.debug") end)
	if not _G._debug then
		_G._debug = print
	end
end)
