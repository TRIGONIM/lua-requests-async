local http = require("http_async")

local get_time   = require'socket'.gettime
local time_start = get_time()

local DO_REQUESTS = 1000 -- 3.2 sec for me

local requests_completed = 0
for i = 1, DO_REQUESTS do
	http.get("https://httpbin.org/get", function(body, len, headers, code)
		print(i, body)
		requests_completed = requests_completed + 1
		if requests_completed == DO_REQUESTS then
			print("Completed in ", get_time() - time_start)
		end
	end)
end

require("copas").loop()


-- Same test for sync requests with luasocket:
--[[
local http  = require("socket.http")
local ltn12 = require 'ltn12'

local function http_get(url)
	local body = {}
	local res, code, headers, status = http.request{
		url  = "https://httpbin.org/get",
		sink = ltn12.sink.table(body)
	}

	local response = table.concat(body)
	return response
end

local get_time = require'socket'.gettime
local time_start = get_time()
for i = 1, 10 do
	print("Making #", i, "request")
	http_get(url)
end

print("Finished", get_time() - time_start)
]]
