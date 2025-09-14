-- Comment: 常用函数

local string_format = string.format
local type = type
local pairs = pairs
local setmetatable = setmetatable
local mrandom = math.random
local sgsub = ngx.re.gsub
local sfind = ngx.re.find
local sreverse = string.reverse
local smatch = ngx.re.match
local sgmatch = ngx.re.gmatch
local table_insert = table.insert
local table_concat = table.concat
local json = require("cjson")
local lfs = require('resty.lfs_ffi')
local OS = require("ffi").os
local os_remove = os.remove
local os_rename = os.rename
local io_open = io.open
local upload = require("resty.upload")
local next = next
local table_isempty = require "table.isempty"
local table_isarray = require "table.isarray"
local table_shallow_clone = require "table.clone"
local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
	new_tab = function () return {} end
end

local _M = {}

-- 创建table
function _M.new_table(narr, nrec)
	return new_tab(narr, nrec)
end

-- 深拷贝
function _M.clone(o)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_object = {}
		lookup_table[object] = new_object
		for key, value in pairs(object) do
			new_object[_copy(key)] = _copy(value)
		end
		return setmetatable(new_object, getmetatable(object))
	end
	return _copy(o)
end

-- 浅拷贝
function _M.shallow_clone(o)
	return table_shallow_clone(o)
end

-- 去除字符串中多余的斜杠字符
function _M.clear_slash(s)
	local r = sgsub(s, "(/+)", "/", "jo")
	return r
end

-- 表是否为空
function _M.is_table_empty(t)
	-- if t == nil or next(t) == nil then
	-- 	return true
	-- else
	-- 	return false
	-- end
	return table_isempty(t)
end

-- 表是否为数组
function _M.table_is_array(t)
	-- if type(t) ~= "table" then return false end
	-- local i = 0
	-- for _ in pairs(t) do
	-- 	i = i + 1
	-- 	if t[i] == nil then return false end
	-- end
	-- return true
	return table_isarray(t)
end

-- 表b中的所有键值对混合到表a中
function _M.mixin(a, b)
	if a and b then
		for k, _ in pairs(b) do
			a[k] = b[k]
		end
	end
	return a
end

-- [0, 10000)随机数
function _M.random()
	return mrandom(0, 10000)
end

-- json序列化
function _M.json_encode(data, empty_table_as_object)
	local json_value
	if json.encode_empty_table_as_object then
		-- empty table encoded as array default
		json.encode_empty_table_as_object(empty_table_as_object or false)
	end
	-- windows已经默认将稀疏数组编码为JSON对象
	-- if require("ffi").os ~= "Windows" then
	-- 	json.encode_sparse_array(true)
	-- end
	-- 测试发现貌似windows也没有开启，所以这里统一都开启
	json.encode_sparse_array(true)
	pcall(function(d) json_value = json.encode(d) end, data)
	return json_value
end

-- json反序列化
function _M.json_decode(str)
	local data
	ok, data = pcall(json.decode, str)
	if ok then
		return data
	end
end

-- 检查字符串是否以特定子字符串开头
function _M.start_with(str, substr)
	if str == nil or substr == nil then
		return false
	end
	local from, _, _ = sfind(str, substr, "jo")
	if not from or from ~= 1 then
		return false
	end
	return true
end

-- 检查字符串是否以特定子字符串结尾
function _M.end_with(str, substr)
	if str == nil or substr == nil then
		return false
	end
	local str_reverse = sreverse(str)
	local substr_reverse = sreverse(substr)
	local from, _, _ sfind(str_reverse, substr_reverse)
	if not from or from ~= 1 then
		return false
	end
	return true
end

-- uri是否与pattern匹配
function _M.is_match(uri, pattern)
	if not pattern then
		return false
	end

	ok = smatch(uri, pattern, "jo")
	if ok then return true else return false end
end

-- 去掉前缀斜线
function _M.trim_prefix_slash(s)
	local str = sgsub(s, "^(//*)", "", "jo")
	return str
end

-- 去掉后缀斜线
function _M.trim_suffix_slash(s)
	local str = sgsub(s, "(//*)$", "", "jo")
	return str
end

-- 去掉空格
function _M.trim_path_spaces(path)
	if not path or path == "" then return path end
	local str = sgsub(path, "( *)", "", "jo")
	return str
end

-- 多余斜线替换单个
function _M.slim_path(path)
	if not path or path == "" then return path end
	local str = sgsub(path, "(//*)", "/", "jo")
	return str
end

-- 将字符串按照指定的分隔符进行分割，返回分割后的结果作为一个数组
function _M.split(str, delimiter, originDelimiter)
	if not str or str == "" then return {} end
	if not delimiter or delimiter == "" then return { str } end

	local inputStr = str .. delimiter
	if originDelimiter then
		inputStr = str .. originDelimiter
	end

	local result = {}
	local it, _ = sgmatch(inputStr, "(.*?)" .. delimiter, "jo")
	if not it then
		return
	end

	while true do
		local m, err = it()
		if err then
			return
		end
		if not m then
			break
		end
		table_insert(result, m[1])
	end
	return result
end

-- basename
function _M.basename(path)
	local m, err = smatch(path, "[^/]+$", "jo")
	if err then
		return nil, err
	end
	if not m then
		return nil, "not match"
	end
	return m[0]
end

-- dirname
function _M.dirname(path)
	path = _M.path_normalize(path)
	path = sgsub(path, "[^/]+/*$", "", "jo")
	return path
end

-- 文件移动
function _M.file_move(src, dest)
	if not src or not dest or not _M.file_exists(src) then
		return nil, "src not exist"
	end
	return os_rename(src, dest)
end

-- 文件删除
function _M.file_remove(path)
	return os_remove(path)
end

-- 获取文件或目录的属性
function _M.attributes(path, attr)
	path = _M.path_normalize(path)
	if OS == "Windows" then
		path = sgsub(path, "/$", "/.", "jo")
	end
	return lfs.attributes(path, attr)
end

-- 目录是否存在
function _M.path_exists(path)
	return _M.attributes(path, "mode") == "directory"
end

-- 文件是否存在
function _M.file_exists(path)
	return _M.attributes(path, "mode") == "file"
end

-- 文件大小
function _M.file_size(path)
	return _M.attributes(path, "size")
end

-- path规范
function _M.path_normalize(path)
	if OS == "Windows" then
		return sgsub(path, "\\", "/", "jo")
	else
		return path
	end
end

-- 递归创建目录
function _M.rmkdir(path)
	path = _M.path_normalize(path)
	if _M.path_exists(path) then
		return true, nil
	end

	if _M.dirname(path) == path then
		return false, "mkdir: unable to create root directory"
	end

	local r, err = _M.rmkdir(_M.dirname(path))
	if not r then
		return false, err.."(creating "..path..")"
	end

	return lfs.mkdir(path)
end

-- 上传文件
-- config: 读取上传文件时的配置参数，{chunk_size=number, recieve_timeout=number}
-- path: 文件保存的路径或者完整路径
-- usePath: path参数是完整路径则为true，否则为false
-- allowed_types: 允许上传的文件类型, 如 {["image/jpeg"]=1, ["image/png"]=1}
-- 返回值: file_name(文件在服务器上保存的完整路径), origin_filename(用户上传的文件原始名称), 
--         file_size(文件大小，新增), file_type(文件的 MIME 类型), extra_fields(一个表，包含除文件外其他普通表单字段的键值对), 
--         失败时的错误信息
function _M.multipart_formdata(config, path, usePath, allowed_types)
	allowed_types = allowed_types or {}
	local form, err = upload:new(config.chunk_size)
	if not form then
		return nil, nil, nil, nil, nil, err
	end

	form:set_timeout(config.recieve_timeout)

	local file
	local file_name, origin_filename, file_type
	local file_size = 0
	local current_field_name
	local extra_fields = {}
	local name = ""
	local value = ""
	while true do
		local typ, res, errs = form:read()
		if not typ then
			return nil, nil, nil, nil, nil, errs
		end

		if typ == "header" then
			if not _M.table_is_array(res) then
				return nil, nil, nil, nil, nil, "res is not array"
			end

			name = res[1]
			value = res[2]

			if name == "Content-Disposition" then
				local name_match = smatch(value, 'name="([^"]+)"', "jo")
				current_field_name = name_match and name_match[1] or nil

				local file_match = smatch(value, 'filename="([^"]+)"', "jo")
				if file_match then
					origin_filename = file_match[1]
				else
					origin_filename = nil
				end
			elseif name == "Content-Type" then
				file_type = value
			end

			if origin_filename and file_type then
				if next(allowed_types) and not allowed_types[file_type] then
					return nil, nil, nil, nil, nil, "file type not allowed"
				end

				if usePath then
					file_name = path
				else
					file_name = string_format("%s%s", path, origin_filename)
				end
				
				file_size = 0
				
				file, err = io_open(file_name, "wb+")
				if not file then
					return nil, nil, nil, nil, nil, err
				end
			end
		elseif typ == "body" then
			if file then
				file:write(res)
				file_size = file_size + #res
			elseif current_field_name then
				if extra_fields[current_field_name] then
					extra_fields[current_field_name] = extra_fields[current_field_name] .. res
				else
					extra_fields[current_field_name] = res
				end
			end
		elseif typ == "part_end" then
			if file then
				-- local _file_size, err = _M.file_size(file_name)
				-- if not err and _file_size then
				-- 	file_size = _file_size
				-- end
				file:close()
				file = nil
			end
		elseif typ == "eof" then
			if current_field_name then
				current_field_name = nil
			end
			break
		else
			-- do nothing
		end
	end

	return file_name, origin_filename, file_size, _M.basename(file_type), extra_fields, nil
end

-- 将数组转换为参数占位符和值列表
function _M.build_condition(arr)
    if type(arr) ~= "table" or #arr == 0 then
        return nil, nil
    end
    local placeholders = {}
    local values = {}
    for _, v in ipairs(arr) do
        table_insert(placeholders, "?")
        table_insert(values, v)
    end
    return table_concat(placeholders, ","), values
end

return _M
