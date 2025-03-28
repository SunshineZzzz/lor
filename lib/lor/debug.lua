-- Comment: 调试开关

local lor_framework_debug = false

local function set_debug(opt)
	lor_framework_debug = opt == true
end

local function get_debug()
	return lor_framework_debug
end

return {
	set_debug = set_debug,
	get_debug = get_debug
}