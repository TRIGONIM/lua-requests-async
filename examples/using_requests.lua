local requests = require("http_requests")

requests.get({"https://httpbin.org/get", {key = "val"}}, function(res, err)
	if err then print(err) return end
	print(res.content)
end)

require("copas").loop()
