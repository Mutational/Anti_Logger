Players = {} -- [serverId] = { name, ids, joined }
Logs = {}

local resourceName = GetCurrentResourceName()
local startedAt = os.time()
local lastDeath = {}

-- ─────────────────────────────── Sending ───────────────────────────────

local function webhookFor(category)
    local c = Config.Logs[category]
    if not c or not c.enabled then return nil end
    local fromConvar = GetConvar('anti_logger_' .. category, '')
    if fromConvar ~= '' then return fromConvar end
    if c.webhook and c.webhook ~= '' then return c.webhook end
    if Config.DefaultWebhook and Config.DefaultWebhook ~= '' then return Config.DefaultWebhook end
    return nil
end

local function cleanFields(fields)
    local out = {}
    for _, f in ipairs(fields or {}) do
        if #out >= 25 then break end
        if f and f.name and f.value ~= nil and tostring(f.value) ~= '' then
            out[#out + 1] = {
                name = Utils.truncate(f.name, 256),
                value = Utils.truncate(f.value, 1024),
                inline = f.inline == true,
            }
        end
    end
    -- leave the key out when empty: FiveM's json can encode {} as an object, which Discord rejects
    return #out > 0 and out or nil
end

function Logs.send(category, title, description, fields, color)
    local url = webhookFor(category)
    if not url then return false end

    local embed = {
        title = Utils.truncate(title or category, 256),
        description = description and Utils.truncate(description, 4000) or nil,
        color = tonumber(color) or Config.Logs[category].color,
        fields = cleanFields(fields),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = Utils.truncate(Config.ServerName, 2048),
            icon_url = Config.FooterIcon ~= '' and Config.FooterIcon or nil,
        },
    }

    if Config.Debug then
        print(('[anti_logger] [%s] %s %s'):format(category, embed.title, description or ''))
    end

    Discord.Send(url, embed, category)
    return true
end

-- ─────────────────────────────── Player cache ──────────────────────────

local function cachePlayer(src)
    local name = GetPlayerName(src)
    if not name then return Players[src] end
    local p = Players[src] or { joined = os.time() }
    p.name = name
    p.ids = Utils.identifiers(src)
    Players[src] = p
    return p
end

-- ─────────────────────────────── Joins / leaves ────────────────────────

AddEventHandler('playerJoining', function()
    local src = tonumber(source)
    if not src then return end
    local p = cachePlayer(src)
    if not p then return end
    p.joined = os.time()

    Logs.send('joins', '✅ Player Joined', ('**%s** joined the server.'):format(Utils.escape(p.name)), {
        Utils.playerField('Player', src),
        { name = 'Players online', value = tostring(#GetPlayers()), inline = true },
    })
end)

AddEventHandler('playerDropped', function(reason)
    local src = tonumber(source)
    if not src then return end
    local p = Players[src] or cachePlayer(src)

    local fields = {
        Utils.playerField('Player', src),
        { name = 'Reason', value = Utils.truncate(reason or 'Unknown', 1000) },
    }
    if p and p.joined then
        fields[#fields + 1] = { name = 'Session', value = Utils.duration(os.time() - p.joined), inline = true }
    end
    fields[#fields + 1] = { name = 'Players online', value = tostring(math.max(0, #GetPlayers() - 1)), inline = true }

    Logs.send('leaves', '❌ Player Left', ('**%s** left the server.'):format(Utils.escape(p and p.name or ('ID ' .. src))), fields)

    Players[src] = nil
    lastDeath[src] = nil
end)

-- ─────────────────────────────── Chat / commands ───────────────────────

AddEventHandler('chatMessage', function(src, _, message)
    src = tonumber(src)
    if not src or src <= 0 or type(message) ~= 'string' or message == '' then return end

    if message:sub(1, 1) == '/' then
        if Config.Chat.commandsToCommandLog then
            Logs.send('commands', '⌨️ Command', ('**%s** used a command.'):format(Utils.escape(Utils.playerName(src))), {
                Utils.playerField('Player', src),
                { name = 'Command', value = Utils.codeBlock(message) },
            })
        end
        return
    end

    Logs.send('chat', '💬 Chat Message', Utils.codeBlock(message, 3900), {
        Utils.playerField('Player', src),
    })
end)

-- ─────────────────────────────── Deaths ────────────────────────────────

RegisterNetEvent('anti_logger:died', function(info)
    local src = tonumber(source)
    if not src or type(info) ~= 'table' then return end

    -- reports come from the player's client, so throttle them
    local now = os.time()
    if lastDeath[src] and now - lastDeath[src] < (Config.Deaths.cooldown or 3) then return end
    lastDeath[src] = now

    local kind = info.kind
    local killer = tonumber(info.killer)
    if kind == 'player' then
        if not killer or not GetPlayerName(killer) then
            kind = 'unknown'
        elseif killer == src then
            kind = 'self'
        end
    end

    -- prefer the server's own position (OneSync), fall back to what the client sent
    local x, y, z = info.x, info.y, info.z
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        if c and (c.x ~= 0.0 or c.y ~= 0.0) then x, y, z = c.x, c.y, c.z end
    end

    local victim = Utils.escape(Utils.playerName(src))
    local cause = Utils.weaponName(info.weapon)
    local title, description, fields

    if kind == 'player' then
        title = '🔫 Player Killed'
        description = ('**%s** killed **%s**.'):format(Utils.escape(Utils.playerName(killer)), victim)
        fields = { Utils.playerField('Killer', killer), Utils.playerField('Victim', src) }
    elseif kind == 'self' then
        title = '💀 Player Died'
        description = ('**%s** killed themselves.'):format(victim)
        fields = { Utils.playerField('Player', src) }
    elseif kind == 'npc' then
        title = '💀 Player Died'
        description = ('**%s** was killed by an NPC.'):format(victim)
        fields = { Utils.playerField('Player', src) }
    else
        title = '💀 Player Died'
        description = ('**%s** died.'):format(victim)
        fields = { Utils.playerField('Player', src) }
    end

    fields[#fields + 1] = { name = 'Cause', value = cause, inline = true }
    if info.inVehicle then fields[#fields + 1] = { name = 'In vehicle', value = 'Yes', inline = true } end
    fields[#fields + 1] = { name = 'Location', value = Utils.coords(x, y, z), inline = true }

    Logs.send('deaths', title, description, fields)
end)

-- ─────────────────────────────── Explosions ────────────────────────────

local ignoredExplosions = {}
for _, t in ipairs(Config.Explosions.ignoreTypes or {}) do ignoredExplosions[t] = true end
local pendingExplosions = {}

AddEventHandler('explosionEvent', function(sender, ev)
    if not Config.Logs.explosions.enabled then return end
    local src = tonumber(sender)
    if not src or type(ev) ~= 'table' then return end
    local kind = tonumber(ev.explosionType)
    if kind and ignoredExplosions[kind] then return end

    -- merge bursts of the same explosion from the same player into one log
    local key = src .. ':' .. tostring(kind)
    local pending = pendingExplosions[key]
    if pending then
        pending.count = pending.count + 1
        if ev.isInvisible then pending.invisible = true end
        return
    end

    pendingExplosions[key] = { count = 1, ev = ev, invisible = ev.isInvisible == true }
    SetTimeout(Config.Explosions.window or 2000, function()
        local d = pendingExplosions[key]
        pendingExplosions[key] = nil
        if not d then return end

        local fields = {
            Utils.playerField('Caused by', src),
            { name = 'Type', value = ('%s (%s)'):format(Utils.explosionName(kind), tostring(kind)), inline = true },
            { name = 'Count', value = tostring(d.count), inline = true },
            { name = 'Location', value = Utils.coords(d.ev.posX, d.ev.posY, d.ev.posZ), inline = true },
        }
        if d.invisible then
            fields[#fields + 1] = { name = '⚠️ Flag', value = 'Invisible explosion. These are often made by mod menus.' }
        end

        Logs.send('explosions', '💥 Explosion',
            ('**%s** caused %s.'):format(Utils.escape(Utils.playerName(src)),
                d.count > 1 and (d.count .. ' explosions') or 'an explosion'),
            fields, d.invisible and 0xED4245 or nil)
    end)
end)

-- ─────────────────────────────── Resources ─────────────────────────────

AddEventHandler('onResourceStart', function(res)
    if res == resourceName or not Config.System.resourceStartStop then return end
    if os.time() - startedAt < (Config.System.bootGrace or 60) then return end
    Logs.send('system', '▶️ Resource Started', ('`%s` was started.'):format(res))
end)

AddEventHandler('onResourceStop', function(res)
    if res == resourceName or not Config.System.resourceStartStop then return end
    Logs.send('system', '⏹️ Resource Stopped', ('`%s` was stopped.'):format(res))
end)

-- ─────────────────────────────── Exports for other scripts ─────────────

-- exports['anti_logger']:Log('menu', { title = '...', description = '...', source = id, target = id, fields = {...}, color = 0xFF0000 })
local function customLog(category, opts)
    if type(category) ~= 'string' or not Config.Logs[category] then
        print(('^3[anti_logger] Log() was called with unknown category "%s".^0'):format(tostring(category)))
        return false
    end
    opts = type(opts) == 'table' and opts or { description = tostring(opts) }
    local fields = {}
    if opts.source then fields[#fields + 1] = Utils.playerField('Player', opts.source) end
    if opts.target then fields[#fields + 1] = Utils.playerField('Target', opts.target) end
    for _, f in ipairs(opts.fields or {}) do fields[#fields + 1] = f end
    return Logs.send(category, opts.title or '📝 Log', opts.description, fields, opts.color)
end

-- exports['anti_logger']:LogMenuAction(staffId, 'Teleport To', targetId, 'optional details')
local function menuAction(staffSrc, action, targetSrc, details)
    local staff = Utils.escape(Utils.playerName(staffSrc))
    local description = ('**%s** used **%s**'):format(staff, Utils.escape(action or 'an action'))
    if targetSrc then
        description = description .. (' on **%s**'):format(Utils.escape(Utils.playerName(targetSrc)))
    end

    local fields = { Utils.playerField('Staff', staffSrc) }
    if targetSrc then fields[#fields + 1] = Utils.playerField('Target', targetSrc) end
    if type(details) == 'table' then
        for k, v in pairs(details) do
            fields[#fields + 1] = { name = tostring(k), value = tostring(v), inline = true }
        end
    elseif details ~= nil then
        fields[#fields + 1] = { name = 'Details', value = tostring(details) }
    end

    return Logs.send('menu', '🛠️ Menu Action', description .. '.', fields)
end

exports('Log', customLog)
exports('LogMenuAction', menuAction)

-- Server-side events (clients can't trigger these, they aren't network events).
AddEventHandler('anti_logger:log', customLog)
AddEventHandler('anti_logger:menuAction', menuAction)

-- ─────────────────────────────── Test command ──────────────────────────

-- Run `logs_test` in the server console (or as an admin with the command.logs_test ace)
-- to send a test message to every enabled category.
RegisterCommand('logs_test', function(src)
    local by = src == 0 and 'the server console' or Utils.playerName(src)
    for category, c in pairs(Config.Logs) do
        if c.enabled then
            if Logs.send(category, '🧪 Test Log', ('Test message for the **%s** category, sent by %s.'):format(category, by)) then
                print(('^2[anti_logger] Test sent to %s^0'):format(category))
            else
                print(('^3[anti_logger] %s has no webhook set^0'):format(category))
            end
        end
    end
end, true)

-- ─────────────────────────────── Startup ───────────────────────────────

CreateThread(function()
    -- pick up players who were already online (resource restarted mid-session)
    for _, id in ipairs(GetPlayers()) do cachePlayer(tonumber(id)) end

    Wait(1000)
    local active, missing = {}, {}
    for category, c in pairs(Config.Logs) do
        if c.enabled then
            if webhookFor(category) then active[#active + 1] = category else missing[#missing + 1] = category end
        end
    end
    table.sort(active)
    table.sort(missing)

    print(('^2[anti_logger] Logging: %s^0'):format(#active > 0 and table.concat(active, ', ') or 'nothing yet'))
    if #missing > 0 then
        print(('^3[anti_logger] Enabled but no webhook: %s (set one in config.lua)^0'):format(table.concat(missing, ', ')))
    end

    Logs.send('system', '🟢 Logger Started', ('Logging %d categories.'):format(#active))
end)
