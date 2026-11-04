# Anti_Logger

A standalone Discord logger for FiveM. No framework needed (works with ESX, QBCore, Qbox or none), no loops running while idle, and every category can go to its own channel.

## What it logs

| Category | What gets logged |
| --- | --- |
| `joins` | Player joins, with identifiers and player count |
| `leaves` | Player leaves, with the disconnect reason and how long they played |
| `chat` | Chat messages |
| `deaths` | Deaths and kills: killer, victim, weapon or cause, location |
| `explosions` | Explosions created by players. Bursts are merged into one log, and invisible explosions (common with mod menus) are flagged red |
| `commands` | Commands typed into chat, txAdmin console commands, and anything your scripts send (see below) |
| `menu` | Staff/admin menu actions, sent from your admin menu with one line of code |
| `admin` | txAdmin kicks, bans, warns, heals, DMs, announcements, revokes and whitelist changes |
| `system` | Logger start, resources started/stopped, scheduled restarts, shutdowns |

## Install

1. Put the `anti_logger` folder in your server's `resources` folder.
2. Open `config.lua` and add your Discord webhook(s):
   - one webhook in `Config.DefaultWebhook` sends everything to one channel, or
   - give each category its own `webhook` to split them into channels.
3. Add `ensure anti_logger` to your `server.cfg`.
4. Restart the server and type `logs_test` in the server console. Every enabled category posts a test message, and the console tells you which ones are missing a webhook.

To make a webhook in Discord: Channel settings → Integrations → Webhooks → New Webhook → Copy Webhook URL.

### Keeping webhooks out of config.lua (optional)

You can set webhooks in `server.cfg` instead. These override `config.lua`:

```
set anti_logger_deaths "https://discord.com/api/webhooks/..."
set anti_logger_chat   "https://discord.com/api/webhooks/..."
```

Use `set`, **not** `setr`. `setr` sends the value to every player's game.

## Config

Everything is in `config.lua` and commented. The main options:

- `Config.Identifiers`: which identifiers to show. IP is off by default.
- `Config.Logs`: turn categories on/off, set webhooks and embed colors.
- `Config.Explosions.ignoreTypes`: explosion types to skip. Steam, flame jets and fire hydrants are skipped by default.
- `Config.TxAdmin.events`: turn individual txAdmin events on/off.
- `Config.Debug`: also print every log to the server console.

## Logging from your own scripts

All exports are **server-side**.

### Menu actions (for admin/staff menus)

```lua
exports['anti_logger']:LogMenuAction(staffId, 'Teleport To', targetId)
exports['anti_logger']:LogMenuAction(staffId, 'Give Item', targetId, { Item = 'bread', Amount = 5 })
exports['anti_logger']:LogMenuAction(staffId, 'Weather Changed', nil, 'Set to RAIN')
```

Put the line in the server-side code of your admin menu, where the action happens. The log shows the staff member's name and identifiers, plus the target's.

### Any category

```lua
exports['anti_logger']:Log('commands', {
    title = '/report',
    description = 'Player sent a report',
    source = source,          -- optional: adds the player's info
    target = targetId,        -- optional: adds a second player
    fields = {                -- optional: extra fields
        { name = 'Message', value = msg },
    },
    color = 0xFF0000,         -- optional: overrides the category color
})
```

You can also use events from other server scripts: `TriggerEvent('anti_logger:log', category, opts)` and `TriggerEvent('anti_logger:menuAction', staffId, action, targetId, details)`. Players can't trigger these.

## Notes

- **Commands:** FiveM has no built-in event for "a player ran a command", so the logger can't see every command automatically. It logs txAdmin console commands automatically. For commands you care about (like `/report` or `/me`), add one `Log` line to that command's server code.
- **Deaths** are detected on the player's client and checked on the server, so they're reliable for normal play. Scripts that kill players without damage (for example setting health to 0) may not trigger a death log.
- **Rate limits:** logs are queued and batched (up to 10 per message), and the logger waits when Discord asks it to, so busy servers don't get their webhooks blocked.
- **Mentions:** Discord IDs are shown as mentions so you can click them, but the logger never pings anyone, even if a player types `@everyone`.
- **Explosion types:** names for types 0–72 are built in. Unknown types are logged by number.

## Performance

Nothing runs on a timer. The client only reacts to the game's own damage event, and the server only reacts to events, so it should sit at 0.00 ms in resmon while idle.

## License

MIT. See `LICENSE`. Credit appreciated but not required.

---

Made by **Antidothe** · Antizone
