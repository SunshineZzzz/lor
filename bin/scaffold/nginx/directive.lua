-- Comment: 用于生成Nginx配置指令
--        : most code is from https://github.com/idevz/vanilla/blob/master/vanilla/sys/nginx/directive.lua

package.path = './app/?.lua;./app/?/init.lua;' .. package.path
package.cpath = './app/library/?.so;' .. package.cpath

local Directive = {}

function Directive:new(env)
	local run_env = 'prod'
	if env ~= nil then run_env = env end
	local instance = {
		run_env = run_env,
		directiveSets = self.directiveSets
	}
	setmetatable(instance, Directive)
	return instance
end

-- 返回lua_package_path指令的字符串，用于设置Lua模块的搜索路径
function Directive:luaPackagePath(lua_path)
	local path = package.path
	if lua_path ~= nil then path = lua_path .. path end
	local res = [[lua_package_path "]] .. path .. [[;;";]]
	return res
end

-- 返回lua_package_cpath指令的字符串，用于设置LuaC模块的搜索路径
function Directive:luaPackageCpath(lua_cpath)
	local path = package.cpath
	if lua_cpath ~= nil then path = lua_cpath .. path end
	local res = [[lua_package_cpath "]] .. path .. [[;;;";]]
	return res
end

-- 返回lua_code_cache指令的字符串，用于控制Lua代码缓存的开关
function Directive:codeCache(bool_var)
	if bool_var == true then bool_var = 'on' else bool_var = 'off' end
	local res = [[lua_code_cache ]] .. bool_var.. [[;]]
	return res
end

-- 返回lua_shared_dict指令的字符串，用于配置共享内存区，这些区域可以在Nginx的多个worker之间共享数据
function Directive:luaSharedDict( lua_lib )
	local ok, sh_dict_conf_or_error = pcall(function() return require(lua_lib) end)
	if ok == false then
		return false
	end
	local res = ''
	if sh_dict_conf_or_error ~= nil then
		for name,size in pairs(sh_dict_conf_or_error) do
			res = res .. [[lua_shared_dict ]] .. name .. ' ' .. size .. ';'
		end
	end
	return res
end

-- 返回init_by_lua指令的字符串，用于在Nginx启动时执行Lua代码
function Directive:initByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[init_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回init_by_lua_file指令的字符串，用于在Nginx启动时执行Lua代码
function Directive:initByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[init_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回init_worker_by_lua指令的字符串，用于在每个worker进程启动时执行Lua代码
function Directive:initWorkerByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[init_worker_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回init_worker_by_lua_file指令的字符串，用于在每个worker进程启动时执行Lua代码
function Directive:initWorkerByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[init_worker_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回set_by_lua指令的字符串，用于在Nginx配置中设置变量的值
function Directive:setByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[set_by_lua require(']] .. lua_lib .. [[');]]
	return res
end

-- 返回set_by_lua_file指令的字符串，用于在 Nginx 配置中设置变量的值
function Directive:setByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[set_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回rewrite_by_lua指令的字符串，用于在Nginx重写请求URI时执行Lua代码
function Directive:rewriteByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[rewrite_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回rewrite_by_lua_file指令的字符串，用于在Nginx重写请求URI时执行Lua代码
function Directive:rewriteByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[rewrite_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回access_by_lua指令的字符串，用于在Nginx访问控制阶段执行Lua代码
function Directive:accessByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[access_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回access_by_lua_file指令的字符串，用于在Nginx访问控制阶段执行Lua代码
function Directive:accessByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[access_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回content_by_lua指令的字符串，用于在Nginx内容生成阶段执行Lua代码
function Directive:contentByLua(lua_lib)
	if lua_lib == nil then return '' end
	-- local res = [[content_by_lua require(']] .. lua_lib .. [['):run();]]
	local res = [[location / {
			content_by_lua require(']] .. lua_lib .. [['):run();
		}]]
	return res
end

-- 返回content_by_lua_file指令的字符串，用于在Nginx内容生成阶段执行Lua代码
function Directive:contentByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[location / {
			content_by_lua_file ]] .. lua_file .. [[;
		}]]
	return res
end

-- 返回header_filter_by_lua指令的字符串，用于在Nginx响应头过滤阶段执行Lua代码
function Directive:headerFilterByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[header_filter_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回header_filter_by_lua_file指令的字符串，用于在Nginx响应头过滤阶段执行Lua代码
function Directive:headerFilterByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[header_filter_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回body_filter_by_lua指令的字符串，用于在Nginx响应体过滤阶段执行Lua代码
function Directive:bodyFilterByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[body_filter_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回body_filter_by_lua_file指令的字符串，用于在Nginx响应体过滤阶段执行Lua代码
function Directive:bodyFilterByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[body_filter_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回log_by_lua指令的字符串，用于在Nginx日志记录阶段执行Lua代码
function Directive:logByLua(lua_lib)
	if lua_lib == nil then return '' end
	local res = [[log_by_lua require(']] .. lua_lib .. [['):run();]]
	return res
end

-- 返回log_by_lua_file指令的字符串，用于在Nginx日志记录阶段执行Lua代码
function Directive:logByLuaFile(lua_file)
	if lua_file == nil then return '' end
	local res = [[log_by_lua_file ]] .. lua_file .. [[;]]
	return res
end

-- 返回静态文件目录的配置字符串
function Directive:staticFileDirectory(static_file_directory)
	if static_file_directory == nil then return '' end
	return static_file_directory
end

-- 返回包含所有指令集合的表，这些指令可以被用来生成完整的Nginx配置
function Directive:directiveSets()
	return {
		['LOR_ENV'] = self.run_env,
		['PORT'] = 80,
		['NGX_PATH'] = '',
		['LUA_PACKAGE_PATH'] = Directive.luaPackagePath,
		['LUA_PACKAGE_CPATH'] = Directive.luaPackageCpath,
		['LUA_CODE_CACHE'] = Directive.codeCache,
		['LUA_SHARED_DICT'] = Directive.luaSharedDict,
		['INIT_BY_LUA'] = Directive.initByLua,
		['INIT_BY_LUA_FILE'] = Directive.initByLuaFile,
		['INIT_WORKER_BY_LUA'] = Directive.initWorkerByLua,
		['INIT_WORKER_BY_LUA_FILE'] = Directive.initWorkerByLuaFile,
		['SET_BY_LUA'] = Directive.setByLua,
		['SET_BY_LUA_FILE'] = Directive.setByLuaFile,
		['REWRITE_BY_LUA'] = Directive.rewriteByLua,
		['REWRITE_BY_LUA_FILE'] = Directive.rewriteByLuaFile,
		['ACCESS_BY_LUA'] = Directive.accessByLua,
		['ACCESS_BY_LUA_FILE'] = Directive.accessByLuaFile,
		['CONTENT_BY_LUA'] = Directive.contentByLua,
		['CONTENT_BY_LUA_FILE'] = Directive.contentByLuaFile,
		['HEADER_FILTER_BY_LUA'] = Directive.headerFilterByLua,
		['HEADER_FILTER_BY_LUA_FILE'] = Directive.headerFilterByLuaFile,
		['BODY_FILTER_BY_LUA'] = Directive.bodyFilterByLua,
		['BODY_FILTER_BY_LUA_FILE'] = Directive.bodyFilterByLuaFile,
		['LOG_BY_LUA'] = Directive.logByLua,
		['LOG_BY_LUA_FILE'] = Directive.logByLuaFile,
		['STATIC_FILE_DIRECTORY'] = Directive.staticFileDirectory
	}
end

return Directive
