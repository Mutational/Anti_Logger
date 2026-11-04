-- Sends embeds to Discord webhooks through a per-webhook queue.
-- Batches up to 10 embeds per message, spaces requests out and obeys
-- Discord's rate limits so busy servers don't get their webhooks blocked.

Discord = {}

local queues = {}
local warned = {}
local MAX_QUEUE = 500      -- oldest logs are dropped past this, so a dead webhook can't eat memory
local SEND_GAP = 1200      -- ms between messages to the same webhook
local MAX_BATCH_CHARS = 5500 -- Discord allows 6000 characters across all embeds in one message

local function validUrl(url)
    if type(url) ~= 'string' then return false end
    return url:find('^https://discord%.com/api/webhooks/') ~= nil
        or url:find('^https://discordapp%.com/api/webhooks/') ~= nil
        or url:find('^https://ptb%.discord%.com/api/webhooks/') ~= nil
        or url:find('^https://canary%.discord%.com/api/webhooks/') ~= nil
end

local function flush(url)
    local q = queues[url]
    if not q or q.busy or #q.items == 0 then return end
    q.busy = true

    local batch, embeds, size = {}, {}, 0
    while #batch < 10 and #q.items > 0 do
        local item = q.items[1]
        if #batch > 0 and size + item.size > MAX_BATCH_CHARS then break end
        table.remove(q.items, 1)
        batch[#batch + 1] = item
        embeds[#embeds + 1] = item.embed
        size = size + item.size
    end

    local payload = json.encode({
        username = Config.BotName ~= '' and Config.BotName or nil,
        avatar_url = Config.BotAvatar ~= '' and Config.BotAvatar or nil,
        embeds = embeds,
        allowed_mentions = { parse = {} }, -- never ping anyone, even if a player types @everyone
    })

    PerformHttpRequest(url, function(status, body, _, errorData)
        local wait = SEND_GAP
        if status == 429 then
            -- rate limited: put the batch back at the front and wait as long as Discord asks
            for i = #batch, 1, -1 do table.insert(q.items, 1, batch[i]) end
            wait = 5000
            local text = body or errorData
            local ok, data = pcall(json.decode, text or '')
            if not ok or type(data) ~= 'table' then
                local retry = type(text) == 'string' and text:match('"retry_after"%s*:%s*([%d%.]+)')
                data = { retry_after = tonumber(retry) }
            end
            if data.retry_after then wait = math.floor(data.retry_after * 1000) + 250 end
        elseif status < 200 or status >= 300 then
            print(('^1[anti_logger] Discord rejected a %s log (HTTP %s). Check that webhook in config.lua.^0')
                :format(q.label, tostring(status)))
            if Config.Debug and (body or errorData) then print(tostring(body or errorData)) end
        end
        SetTimeout(wait, function()
            q.busy = false
            flush(url)
        end)
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

function Discord.Send(url, embed, label)
    if not validUrl(url) then
        if not warned[url] then
            warned[url] = true
            print(('^3[anti_logger] The webhook for "%s" doesn\'t look like a Discord webhook URL, so nothing will be sent.^0')
                :format(tostring(label)))
        end
        return
    end

    local q = queues[url]
    if not q then
        q = { items = {}, busy = false, label = label }
        queues[url] = q
    end
    if #q.items >= MAX_QUEUE then table.remove(q.items, 1) end

    q.items[#q.items + 1] = { embed = embed, size = #json.encode(embed) }
    flush(url)
end
