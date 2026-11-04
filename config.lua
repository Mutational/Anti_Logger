Config = {}

-- ─────────────────────────────── General ───────────────────────────────

Config.ServerName = 'My FiveM Server' -- shown in the footer of every log
Config.BotName    = 'Server Logs'     -- name the webhook posts as
Config.BotAvatar  = ''                -- image URL for the webhook avatar (optional)
Config.FooterIcon = ''                -- small image URL next to the footer text (optional)

-- Used by any category below whose own webhook is empty.
-- Put one webhook here to send everything to a single channel,
-- or leave it empty and give each category its own channel.
Config.DefaultWebhook = ''

-- Which player identifiers to show in logs.
-- IP is off by default: only turn it on if your staff channel is private.
Config.Identifiers = {
    discord = true,  -- shown as a Discord mention (never pings anyone)
    license = true,
    fivem   = true,
    steam   = false,
    xbl     = false,
    live    = false,
    ip      = false,
}

-- ─────────────────────────────── Categories ────────────────────────────
-- enabled  : turn a category on or off
-- webhook  : Discord webhook URL for this category ('' = use DefaultWebhook)
-- color    : embed side color (hex)
--
-- Tip: instead of pasting webhooks here you can put them in server.cfg:
--   set anti_logger_deaths "https://discord.com/api/webhooks/..."
-- Use `set`, NOT `setr` (setr sends the value to every player).

Config.Logs = {
    joins      = { enabled = true, webhook = '', color = 0x57F287 }, -- player joined
    leaves     = { enabled = true, webhook = '', color = 0xED4245 }, -- player left (with reason + session time)
    chat       = { enabled = true, webhook = '', color = 0x5865F2 }, -- chat messages
    deaths     = { enabled = true, webhook = '', color = 0x99AAB5 }, -- deaths and kills
    explosions = { enabled = true, webhook = '', color = 0xE67E22 }, -- explosions created by players
    commands   = { enabled = true, webhook = '', color = 0xFEE75C }, -- commands (see README)
    menu       = { enabled = true, webhook = '', color = 0x9B59B6 }, -- admin/staff menu actions (via export)
    admin      = { enabled = true, webhook = '', color = 0xEB459E }, -- txAdmin kicks, bans, warns, heals, DMs...
    system     = { enabled = true, webhook = '', color = 0x95A5A6 }, -- logger start, resource start/stop, restarts
}

-- ─────────────────────────────── Options ───────────────────────────────

Config.Chat = {
    commandsToCommandLog = true, -- chat lines starting with "/" go to the commands category instead of chat
}

Config.Deaths = {
    cooldown = 3, -- seconds; ignores repeat death reports from the same player inside this window
}

Config.Explosions = {
    window = 2000, -- ms; identical explosions from one player inside this window are merged into one log
    -- Explosion types to ignore (see README for the full list).
    -- 11 = steam jets, 12 = flame jets, 13 = fire hydrants: harmless map effects.
    ignoreTypes = { 11, 12, 13 },
}

Config.System = {
    resourceStartStop = true, -- log when a resource is started/stopped
    bootGrace = 60,           -- seconds after the logger starts during which resource starts aren't logged (server boot)
}

Config.TxAdmin = {
    enabled = true,
    -- Turn individual txAdmin events on/off.
    events = {
        announcement            = true,
        playerDirectMessage     = true,
        playerKicked            = true,
        playerWarned            = true,
        playerBanned            = true,
        playerHealed            = true,
        actionRevoked           = true,
        whitelistPlayer         = true,
        whitelistPreApproval    = true,
        whitelistRequest        = true,
        adminAuth               = false, -- fires every time an admin's status refreshes; noisy
        configChanged           = true,
        consoleCommand          = true,
        scheduledRestart        = true, -- fires at every restart warning (30, 15, 10, 5... min)
        scheduledRestartSkipped = true,
        serverShuttingDown      = true,
    },
}

Config.Debug = false -- print every log to the server console as well
