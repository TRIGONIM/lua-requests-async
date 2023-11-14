--[[
🤦‍♂️ In an attempt to minimally modify the official socket.http library,
	this file is already close to it in size...

So there is still a lot of work to be done here:

1. Make it more universal. Like resty.mysql or lua-redis, which have functions like connection.new(),
	which return a socket object that can be modified to work with copas or luasec if desired
2. Build a mash-up of luasec, copas, and luasocket's http libraries into one file
	so you don't have to depend on versions of each of them, but take the first point in mind.
	The result should have the optional ability to execute https requests asynchronously if a user needs it
3. Don't forget about safe redirects
4. Maybe add ability to get reqt table after or during request
]]


-- local _, copas = pcall(require, "copas") -- should be before socket.http
-- /\ require it manually before this lib if you want to use copas

local socket = require("socket")
local http   = require("socket.http")
local sourl  = require("socket.url")
local ltn12  = require("ltn12")

http.USERAGENT = "lua-requests" -- default

do -- workaround to use dynamic port and timeout per request. #note maybe it is unnecessary, #todo check
	local metat = nil
	local get_private_socket_http_mt = function()
		if metat then return metat end

		-- fake connection to get metatable
		local h = http.open_orig("0.0.0.0", 80, function()
			-- local so = socket.tcp()
			-- so:settimeout(0)
			-- return so

			local so = {} -- instead of fake connection
			function so:settimeout() return 1 end -- should return 1 for socket.try
			function so:connect() return 1 end
			return so
		end)

		metat = getmetatable(h)
		return metat
	end

	-- overwritten function for ability to change port on fly and set custom timeout per request
	http.open_orig = http.open_orig or http.open
	function http.open(host, port, create) -- this args taken from reqt directly so I can't change them,
                                           -- but I needed to change port and timeout on fly some way
		local c = socket.try(create())
		local h = setmetatable({ c = c }, get_private_socket_http_mt())

		h.try = socket.newtry(function() h:close() end)

		-- ._timeout is a custom hardcoded field
		local to = c._timeout or http.TIMEOUT or 60
		h.try(c:settimeout(to))

		h.try(c:connect(host, c._port or port or http.PORT))
		return h
	end
end

-- local PrintTable = require("gmod.globals").PrintTable
-- PrintTable( sourl.parse("https://gm-donate.net/foo/bar?qwe=rty&uio=pos#si") )

-- reqt: {url, headers, timeout, method, body, create = function} (host, port, sslparams)
local function request(reqt)
	local t = {}
	reqt.sink = ltn12.sink.table(t)

	-- luasec requires port to be set for https
	local u = sourl.parse(reqt.url)
	if reqt.ssl == nil then -- not false. Exactly nil
		reqt.ssl = (reqt.scheme or u.scheme) == "https"
	end

	reqt.host = reqt.host or u.host
	reqt.port = reqt.port or u.port
	if not reqt.port then
		reqt.port = reqt.ssl and 443 or 80
	end

	if reqt.body then
		reqt.source = ltn12.source.string(reqt.body)

		reqt.headers = reqt.headers or {}
		reqt.headers["content-length"] = string.len(reqt.body)
		-- reqt.headers["content-type"] = "application/x-www-form-urlencoded" -- may override user's content-type
		-- reqt.method = reqt.method or "POST" -- PUT, PATCH?
	end

	local ok, code, headers, status = http.request(reqt)
	if ok then
		return table.concat(t), code, headers, status
	else
		return nil, code
	end
end

local function srequest(method, url, body_, extra_headers_, timeout_, create_func_)
	local reqt = {
		url = url,
		timeout = timeout_,
		headers = extra_headers_,
		method = method or "GET",
		body = body_,

		-- host = "httpbin.org",
		-- port = 443,
	}

	reqt.create = function() -- bind reqt to create_func
		return create_func_(reqt)
	end

	return request(reqt)
end



local get_create_func
local copas_create_func = function(reqt)
	if not get_create_func then
		-- this func retuns copas wrapped socket
		get_create_func = require("copas.http").getcreatefunc
	end

	local create = get_create_func(reqt) -- reqt: {sslparams = table, redirect = "all", ...}
	local skt = create(reqt)

	-- set custom fields for overwritten http.open, which located above
	skt._port    = reqt.port -- might have changed in the "create" func
	skt._timeout = reqt.timeout

	return skt
end


-- Forward calls to the real connection object.
local function reg(conn)
	local mt = getmetatable(conn.sock).__index
	for name, method in pairs(mt) do
		if type(method) == "function" then
			conn[name] = function (self, ...)
				return method(self.sock, ...)
			end
		end
	end
end

local ssl
local luasec_warned
local sync_create_func = function(reqt)
	if not ssl then
		local sslok, sssl = pcall(require, "ssl")
		-- local _, ssl_https
		if not sslok and not luasec_warned then
			luasec_warned = true
			print("can't require luasec. https requests will not work")
		-- else
		-- 	_, ssl_https = pcall(require, "ssl.https")
		end

		ssl = sslok and sssl
	end

	local conn = {}
	conn.sock = socket.try(socket.tcp())

	local st = getmetatable(conn.sock).__index.settimeout
	function conn:settimeout(to)
		return st(self.sock, reqt.timeout or to)
	end

	if ssl and reqt.ssl then
		-- conn = ssl_https.tcp(reqt.sslparams)() -- no timeout controls

		function conn:connect(host, port)
			socket.try(self.sock:connect(host, port))
			self.sock = socket.try(ssl.wrap(self.sock, reqt.sslparams or {
				mode     = "client",
				protocol = "any",
				options  = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
				verify   = "none",
			}))
			self.sock:sni(host)
			self.sock:settimeout(reqt.timeout)
			socket.try(self.sock:dohandshake())
			reg(self)
			return 1
		end

	else
		-- conn = socket.tcp()
		-- if reqt.timeout then
		-- 	conn:settimeout(reqt.timeout)
		-- 	conn:connect(reqt.host, reqt.port) -- if we connected here, then the http.open will not able to connect with own options
		-- end

		function conn:connect(host, port)
			socket.try(self.sock:connect(host, port))
			reg(self)
			return 1
		end
	end

	-- conn._timeout = reqt.timeout
	return conn
end

local function copas_request(method, url, body_, extra_headers_, timeout_)
	return srequest(method, url, body_, extra_headers_, timeout_, copas_create_func)
end

local function sync_request(method, url, body_, extra_headers_, timeout_)
	return srequest(method, url, body_, extra_headers_, timeout_, sync_create_func)
end


local build_query do
	local function string_URLEncode(str)
		return string.gsub(string.gsub(str, "\n", "\r\n"), "([^%w.])", function(c)
			return string.format("%%%02X", string.byte(c))
		end)
	end

	function build_query(tParams)
		local kvs = {}
		for k, v in pairs(tParams) do
			table.insert(kvs, k .. "=" .. string_URLEncode( tostring(v) ))
		end
		return table.concat(kvs, "&")
	end
end

return {
	request = request,

	sync_request = sync_request,
	copas_request = copas_request,

	copas_create_func = copas_create_func,
	sync_create_func  = sync_create_func,

	build_query = build_query
}
