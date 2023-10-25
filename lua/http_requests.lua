--[[-------------------------------------------------------------------------
	2019.12.11 by _AMD_ on TRIGON.IM (c)
	HTTP wrapper inspired by Python requests

	2022.05.06 правки .post, .get, ...
	2022.11.10 избавился от table.Inherit, форс хедера для copas http
		ver 2: fix form-data for copas. Also modified http_async.lua
	2023.03.20 переделал под коллбеки вместо deferred. Deferred реализуется при помощи расширения
	2023.03.29 require cjson для pure lua environment
---------------------------------------------------------------------------]]

local pcallok, http = pcall(require, "http_async")
local http_request = pcallok and http.request or HTTP -- second for gmod

local json_encode, json_decode -- may be nil
if util and util.JSONToTable then -- gmod environment
	json_encode = util.TableToJSON
	json_decode = util.JSONToTable
else -- pure lua environment
	local ok_req, json = pcall(require, "cjson")
	if not ok_req then return end

	json_encode = function(t) return json.encode(t) end
	json_decode = function(js)
		local ok, res = pcall(json.decode, js) -- nil при невозможности декода
		if not ok then print( debug.traceback("can't decode json\n\t" .. res) ) return nil end
		return res
	end

end

local wrap_response = function(code, body, headers)
	local R = {}
	R.status_code = code
	R.headers = headers
	R.content = body

	function R.json()
		if rawget(R, "json_cache") == nil then
			R.json_cache = json_decode(body) or false
		end
		return R.json_cache
	end

	-- res.anykey == res.json().anykey
	return setmetatable(R, {
		__index = function(self, k)
			if k == "next" then return nil end
			local j = self.json()
			return j and j[k]
		end
	})
end


local M = {}

-- M.request{"GET", "url", .params, .headers, .json/data}
-- :next > {.json(), .status_code, .headers, .content}
function M.request(t, cb)
	-- t.headers = t.headers or {}
	-- for k, v in pairs(t.headers) do
	-- 	t.headers[k] = nil
	-- 	t.headers[k:lower()] = v
	-- end

	local struct = {
		url        = t[2],
		method     = t[1],
		parameters = t.params, -- для GET под капотом добавляет к ссылке
		headers    = t.headers,
		body       = t.json    and json_encode(t.json) or t.data,
		type       = t.headers and t.headers["content-type"],
	}

	struct.success = cb and function(code, body, headers)
		local resp = wrap_response(code, body, headers)
		resp.request_structure = struct
		cb(resp, false)
	end

	struct.failed = cb and function(reason)
		cb(false, reason)
	end

	local ok = http_request(struct)
	if not ok then
		cb(false, "http_request() error")
	end
end

local req = function(base, extra, cb)
	return M.request( setmetatable(base, {__index = extra}), cb )
end

-- local callback = fc{PRINT, fn.Apply, fl.property("json")}
-- local callback = function(t) print( t.content ) end

function M.get(t, cb) -- {url, params, ...}
	return req({"GET", t[1], params = t[2]}, t, cb)
end

-- M.get({"https://httpbin.org/get", {key = "val"}}, callback)
-- M.get({"https://httpbin.org/get", params = {key = "val"}}, callback)

function M.post(t, cb) -- {url, data, json, ...}
	return req({"POST", t[1], data = t[2], json = t[3]}, t, cb)
end

-- M.post({"https://httpbin.org/post", json = {json_data = true}}, callback)
-- M.post({"https://httpbin.org/post", nil, {json_data = true}}, callback)
-- M.post({"https://httpbin.org/post", data = "string data"}, callback)
-- M.post({"https://httpbin.org/post", "string data"}, callback)
-- M.post({"https://httpbin.org/post", params = {foo = "123", bar = "baz"}}, callback) -- form-data

function M.put(t, cb) -- {url, data, ...}
	return req({"PUT", t[1], data = t[2]}, t, cb)
end

-- M.put({"https://httpbin.org/put", "string data"}, callback)
-- M.put({"https://httpbin.org/put", json = {json_data = true}}, callback)

function M.delete(t, cb) -- {url, ...}
	return req({"DELETE", t[1]}, t, cb)
end

-- M.delete({"https://httpbin.org/delete"}, callback)

function M.head(t, cb) -- {url, ...}
	return req({"HEAD", t[1]}, t, cb)
end

-- M.head({"https://httpbin.org"}, callback)

-- require("copas").loop()

return M
