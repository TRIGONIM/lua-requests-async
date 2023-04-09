# Асинхронные HTTP запросы на Lua

- 🔬 Минимализм
- 🚀 Асинхронное выполнение сотен или тысяч http запросов в секунду
- 🔒 Поддержка https
- 🙅‍♂️ Nginx не требуется
- 🐍 Удобная обертка `http_requests.lua`, подобна питоновской requests
- 📦 Возможность отправки `multipart/form-data` запросов
- 🤖 Идеально для парсеров, телеграм ботов, производительных API библиотек
- Возможность выполнения синхронных запросов
- Легко использовать даже в Garry's Mod


## Установка

> `luarocks install lua-requests-async`

## Использование

Дополнительные примеры использования вы можете найти [здесь](/examples)

### Использование базовой функции

```lua
-- http_async.lua
local http = require("http_async")
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
```

### Использование обертки-хелпера

```lua
-- http_requests.lua
local requests = require("http_requests")

requests.get({"https://httpbin.org/get", {key = "val"}}, function(res)
	print(res.content)
end)

require("copas").loop()
```

В любом случае в вашем приложении, например в главном файле в конце, **должна** использоваться одна из следующих конструкций:

```lua
-- Выполнит все накопившиеся http запросы и завершит выполнение скрипта
require("copas").loop()

-- Приложение никогда не завершится само по себе
while true do require("copas").step() end
```

## Документация

Пока что документации нет, но каждый файл детально прокомментирован и в них можно найти дополнительные примеры, а также объяснения непонятных моментов. Просто откройте файл и найдите нужную функцию. Можете также воспользоваться примерами

## TODO

- Добавить на readme список тех, кто использует библиотеку, например git.io/ggram
- Встроить поддержку [multipart](/examples/sending_multipart.lua) "из коробки" без необходимости вручную что-то устанавливать
- Добавлять дополнительные методы и возможности из питновского requests
