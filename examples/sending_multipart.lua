-- Предварительно установите https://github.com/Kong/lua-multipart
-- luarocks install multipart

-- Загрузите файл testfile.png в директорию модуля
-- Выполните `lua examples/sending_multipart.lua`

local bot_token = "1234:aabbccddeeff" -- @BotFather
local chat_id   = 123456 -- @jsonson_bot
local file_name = "testfile.png" -- относительный путь к файлу, который будет отправлен от пути, с которого выполняется запуск скрипта

local pngContent = io.open(file_name, "rb"):read("*a")
local Multipart  = require("multipart")

local form_data = Multipart()
form_data:set_simple("chat_id", chat_id)
form_data:set_simple("photo", pngContent, file_name, "image/png")

require("http_requests").post({"https://api.telegram.org/bot" .. bot_token .. "/sendPhoto", form_data:tostring(), headers = {
	["content-type"]  = "multipart/form-data;boundary=" .. Multipart.RANDOM_BOUNDARY,
}}, function(r) print(r.content) end)

require("copas").loop()
