-- Comment: web应用包装

local type = type
local version = require("lor.version")
local optDebug = require("lor.debug")
local Group = require("lor.lib.router.group")
local Router = require("lor.lib.router.router")
local Request = require("lor.lib.request")
local Response = require("lor.lib.response")
local Application = require("lor.lib.application")
local Wrap = require("lor.lib.wrap")
local Debug = require("lor.lib.debug")

local createApplication = function(options)
	if options and options.debug and type(options.debug) == 'boolean' then
		optDebug.set_debug(options.debug)
	end

	local app = Application:new()
	app:init(options)

	return app
end

local lor = Wrap:new(createApplication, Router, Group, Request, Response)
lor.version = version

return lor
