-- Logs the events txAdmin broadcasts (txAdmin:events:<name>).
-- Each event passes one table; the fields differ between events and txAdmin
-- versions, so known fields are shown nicely and anything else is listed as-is.

if not Config.TxAdmin.enabled then return end

local EVENTS = {
    announcement            = { category = 'admin',    title = '📢 Announcement' },
    playerDirectMessage     = { category = 'admin',    title = '✉️ Direct Message' },
    playerKicked            = { category = 'admin',    title = '👢 Player Kicked' },
    playerWarned            = { category = 'admin',    title = '⚠️ Player Warned' },
    playerBanned            = { category = 'admin',    title = '🔨 Player Banned' },
    playerHealed            = { category = 'admin',    title = '💉 Player Healed' },
    actionRevoked           = { category = 'admin',    title = '↩️ Action Revoked' },
    whitelistPlayer         = { category = 'admin',    title = '📝 Whitelist Changed' },
    whitelistPreApproval    = { category = 'admin',    title = '📝 Whitelist Pre-Approval' },
    whitelistRequest        = { category = 'admin',    title = '📝 Whitelist Request' },
    adminAuth               = { category = 'admin',    title = '🔐 Admin Status Changed' },
    configChanged           = { category = 'system',   title = '⚙️ txAdmin Settings Changed' },
    consoleCommand          = { category = 'commands', title = '💻 Console Command' },
    scheduledRestart        = { category = 'system',   title = '⏰ Scheduled Restart' },
    scheduledRestartSkipped = { category = 'system',   title = '⏭️ Scheduled Restart Skipped' },
    serverShuttingDown      = { category = 'system',   title = '🛑 Server Shutting Down' },
}

-- Field names txAdmin commonly uses, in the order they should appear.
local KNOWN = {
    { key = 'author',             label = 'By' },
    { key = 'adminName',          label = 'Admin' },
    { key = 'targetName',         label = 'Player' },
    { key = 'reason',             label = 'Reason' },
    { key = 'message',            label = 'Message' },
    { key = 'command',            label = 'Command' },
    { key = 'actionType',         label = 'Action' },
    { key = 'actionId',           label = 'Action ID',  inline = true },
    { key = 'durationTranslated', label = 'Duration',   inline = true },
    { key = 'expiration',         label = 'Expires',    inline = true },
    { key = 'secondsRemaining',   label = 'Time left',  inline = true },
    { key = 'isAdmin',            label = 'Is admin',   inline = true },
}

local SKIP = { targetNetId = true, targetIds = true, target = true, targetLicense = true }

local function valueText(key, v)
    if key == 'expiration' and type(v) == 'number' then
        if v <= 0 then return 'Never' end
        return os.date('!%Y-%m-%d %H:%M UTC', math.floor(v))
    end
    if key == 'secondsRemaining' then return Utils.duration(v) end
    if key == 'command' then return Utils.codeBlock(v) end
    return tostring(v)
end

local function handle(name, info, data)
    if type(data) ~= 'table' then data = {} end
    local fields, used = {}, {}

    -- the targeted player, if the event names one that's online
    local netId = tonumber(data.targetNetId or data.target)
    if netId and netId > 0 and GetPlayerName(netId) then
        fields[#fields + 1] = Utils.playerField('Player', netId)
        used.targetName = true
    elseif netId == -1 then
        fields[#fields + 1] = { name = 'Player', value = 'Everyone' }
        used.targetName = true
    end

    for _, k in ipairs(KNOWN) do
        local v = data[k.key]
        if v ~= nil and not used[k.key] and type(v) ~= 'table' and tostring(v) ~= '' then
            fields[#fields + 1] = { name = k.label, value = valueText(k.key, v), inline = k.inline }
        end
        used[k.key] = true
    end

    if type(data.targetIds) == 'table' and #data.targetIds > 0 then
        fields[#fields + 1] = { name = 'Identifiers', value = Utils.codeBlock(table.concat(data.targetIds, '\n')) }
    end

    -- anything else txAdmin sent
    for k, v in pairs(data) do
        if not used[k] and not SKIP[k] and type(v) ~= 'table' and #fields < 24 then
            fields[#fields + 1] = { name = tostring(k), value = tostring(v), inline = true }
        end
    end

    Logs.send(info.category, info.title, nil, fields)
end

for name, info in pairs(EVENTS) do
    if Config.TxAdmin.events[name] then
        AddEventHandler('txAdmin:events:' .. name, function(data)
            handle(name, info, data)
        end)
    end
end
