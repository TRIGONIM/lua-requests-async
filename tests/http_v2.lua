local _, copas = pcall(require, "copas") -- should be before socket.http

local http = require("misc.http")
local sync_request  = http.sync_request
local copas_request = http.copas_request
local json_decode = require("cjson").decode

local run_sync
local function request(...)
	if run_sync then
		return sync_request(...)
	else
		return copas_request(...)
	end
end

local tests = {}

local function test(descr, callback, params)
	tests[#tests + 1] = {
		descr = descr,
		callback = callback,
		params = params,
	}
end

local function run_tests(typ)
	run_sync = typ == "sync"

	local error_occured = false
	for _, t in ipairs(tests) do
		print((typ or "copas") .. " >> " .. t.descr)
		for _, param in ipairs(t.params) do
			local ok, err = pcall(t.callback, param)
			local paramstr = type(param) == "table" and table.concat(param, "-") or tostring(param)
			if ok then
				print("\t> OK " .. paramstr)
			else
				print("\t> ERR " .. paramstr .. " " .. err)
				error_occured = true
			end
		end
	end

	if error_occured then
		print("❌ some test failed")
		os.exit(1)
	end
end

test("Simple request", function()
	local body = "BodyЗапроса 🔥 🤦‍♂️ ;%:?*()\n\n\t\tHello World"
	local res, code = request("POST", "http://httpbin.org/post", body, {
		["user-agent"] = "lua-requests (https://github.com/TRIGONIM/lua-requests-async)",
		["X-Some-Header"] = 123,
	})
	local dat = json_decode(res)
	assert(code == 200, "HTTP code expected 200, got " .. code)
	assert(dat.data == body, "expected " .. body .. ", got " .. tostring(dat.data))
	assert(dat.headers["X-Some-Header"] == "123", "expected 123, got " .. tostring(dat.headers["X-Some-Header"]))
	assert(dat.headers["User-Agent"]:match("^lua%-requests"), "user agent not match")
	assert(dat.url == "http://httpbin.org/post", "URL not match expected http://httpbin.org/post, got " .. tostring(dat.url))
end, {"just GET trequest"})

test("Check if methods sends correct", function(method)
	local _, code = request(method, "http://httpbin.org/" .. method:lower())
	assert(code == 200, "expected 200, got " .. code)
end, {"GET", "POST", "PATCH", "PUT", "DELETE"})

test("Check https and http", function(scheme)
	local res = request("GET", scheme .. "://httpbin.org/get")
	local dat = json_decode(res)
	assert(dat.url:match("^" .. scheme .. "://"), scheme .. " expected, got " .. dat.url)
end, {"https", "http"})

test("Check forcing port", function(port_scheme_pair)
	local port, scheme = unpack(port_scheme_pair)
	local ssl = port == 443

	-- local res, code = request("POST", scheme .. "://httpbin.org:" .. port .. "/post")
	local ok, res, code = pcall(request, "POST", scheme .. "://httpbin.org:" .. port .. "/post") -- copas required pcall this func for https:80
	if not ok then res, code = nil, res end

	if scheme == "http" and ssl then
		assert(res and code == 400, "We send insecure request to ssl port. Expected 400 from serverm but got " .. code) -- not json
	elseif scheme == "http" and not ssl then
		assert(res and code == 200, "We send insecure request to insecure port. Expected 200 from serverm but got " .. code)
	elseif scheme == "https" and ssl then
		assert(res and code == 200, "We send secure request to secure port. Expected 200 from serverm but got " .. code)
	elseif scheme == "https" and not ssl then
		-- code (err) == "wrong version number"
		assert(not res, "We send secure request to insecure port. Expected error from client, but got " .. tostring(code))
	end
end, {{80, "http"}, {443, "https"}, {80, "https"}, {443, "http"}})

test("Check form-data and content-type header recognition", function(param)
	local header = param == "with header" and "application/x-www-form-urlencoded" or nil
	local res, code = request("POST", "https://httpbin.org/post", "a=1&b=2", {
		["content-type"] = header,
	})
	assert(res, "no response. got error " .. code)
	local dat = json_decode(res)
	if header then assert(dat.form.a, "Form value expected")
	else           assert(not dat.form.a, "Form value not expected")
	end
end, {"with header", "without header"})

test("Timeout check", function(scheme)
	local res, code = request("GET", scheme .. "://httpbin.org/delay/3", nil, nil, 2)
	assert(not res, "'timeout' expected, got " .. code)
end, {"https", "http"})

run_tests("sync")
copas.loop(run_tests)
