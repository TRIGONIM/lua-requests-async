local http = require("http_async")

-- simple POST request
http.post("https://httpbin.org/post", {
	param1 = "value1",
	param2 = "value2",
}, function(body, len, headers, code)
	print(string.format("len: %d\ncode: %d\nbody: %s", len, code, body))
	print("origin headers:", require("cjson").encode(headers))
end, function(err) print("post err", err) end, {headername = "value"})

-- advanced POST request
http.request({
	url        = "https://httpbin.org/post?foo=bar",
	method     = "POST",
	body       = "body payload",
	success    = function(code, body, headers)
		assert(code == 200)
		assert(headers["connection"] == "close")
		print(body)
	end,
})

require("copas").loop()
