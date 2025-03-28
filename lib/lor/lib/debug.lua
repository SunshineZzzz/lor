-- Comment: 调试输出
 
local pcall = pcall
local type = type
local ipairs = ipairs
local optDebug = require("lor.debug")

local function debug(...)
	if not optDebug.get_debug() then
		return
	end

	local info = { ... }
	if info and type(info[1]) == 'function' then
		pcall(function() info[1]() end)
	elseif info and type(info[1]) == 'table' then
		for i, v in ipairs(info[1]) do
			print(i, v)
		end
	elseif ... ~= nil then
		print(...)
	else
		print("debug not works...")
	end
end

return debug
