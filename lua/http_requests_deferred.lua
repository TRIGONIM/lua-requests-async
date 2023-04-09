-- requires: https://github.com/zserge/lua-promises
-- `luarocks install --server=http://luarocks.org/dev lua-promises`

local deferred = require("deferred")
local requests = require("http_requests")

local M_def = setmetatable({}, {
	__index = function(self, k)
		local func = requests[k]
		if not func then return end

		return function(t)
			local d = deferred.new()
			func(t, function(res, err)
				d[err and "reject" or "resolve"](d, err or res)
			end)
			return d
		end
	end
})

-- local callback = function(t) t.json = nil t.request_structure = nil print( require("cjson").encode(t) ) end
-- M_def.get{"https://httpbin.org/get", {key = "val"}}:next(callback, print)
-- require("copas").loop()

return M_def
