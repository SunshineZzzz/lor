-- Comment: Nginx服务管理
--        : most code is from https://github.com/ostinelli/gin/blob/master/gin/cli/base_launcher.lua

-- 创建目录
local function create_dirs(necessary_dirs)
	for _, dir in pairs(necessary_dirs) do
		os.execute("mkdir -p " .. dir .. " > /dev/null")
	end
end

-- Nginx配置内容写入对应配置文件路径中
local function create_nginx_conf(nginx_conf_file_path, nginx_conf_content)
	local fw = io.open(nginx_conf_file_path, "w")
	fw:write(nginx_conf_content)
	fw:close()
end

-- 删除指定路径的Nginx配置文件
local function remove_nginx_conf(nginx_conf_file_path)
	os.remove(nginx_conf_file_path)
end

-- 执行Nginx命令
local function nginx_command(env, nginx_conf_file_path, nginx_signal)
	local env_cmd = ""

	if env ~= nil then env_cmd = "-g \"env LOR_ENV=" .. env .. ";\"" end
	local cmd = "openresty " .. nginx_signal .. " " .. env_cmd .. " -p `pwd`/ -c " .. nginx_conf_file_path
	print("execute: " .. cmd)
	return os.execute(cmd)
end

-- 启动Nginx
local function start_nginx(env, nginx_conf_file_path)
	return nginx_command(env, nginx_conf_file_path, '')
end

-- 停止Nginx
local function stop_nginx(env, nginx_conf_file_path)
	return nginx_command(env, nginx_conf_file_path, '-s stop')
end

-- 重新加载Nginx
local function reload_nginx(env, nginx_conf_file_path)
	return nginx_command(env, nginx_conf_file_path, '-s reload')
end


local NginxHandle = {}
NginxHandle.__index = NginxHandle

function NginxHandle.new(necessary_dirs, nginx_conf_content, nginx_conf_file_path)
	local instance = {
		-- Nginx配置内容
		nginx_conf_content = nginx_conf_content,
		-- Nginx路径
		nginx_conf_file_path = nginx_conf_file_path,
		-- 必须路径
		necessary_dirs = necessary_dirs
	}
	setmetatable(instance, NginxHandle)
	return instance
end

-- 创建路径，启动Nginx
function NginxHandle:start(env)
	create_dirs(self.necessary_dirs)
	-- create_nginx_conf(self.nginx_conf_file_path, self.nginx_conf_content)

	return start_nginx(env, self.nginx_conf_file_path)
end

-- 停止Nginx
function NginxHandle:stop(env)
	local result = stop_nginx(env, self.nginx_conf_file_path)
	-- remove_nginx_conf(self.nginx_conf_file_path)

	return result
end

-- 重新加载Nginx
function NginxHandle:reload(env)
	-- remove_nginx_conf(self.nginx_conf_file_path)
	create_dirs(self.necessary_dirs)
	-- create_nginx_conf(self.nginx_conf_file_path, self.nginx_conf_content)

	return reload_nginx(env, self.nginx_conf_file_path)
end

return NginxHandle
