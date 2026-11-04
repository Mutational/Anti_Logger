Utils = {}

function Utils.truncate(s, max)
    s = tostring(s or '')
    if #s > max then
        return s:sub(1, max - 3) .. '...'
    end
    return s
end

-- Escape Discord markdown so player names can't break the formatting.
function Utils.escape(s)
    return (tostring(s or ''):gsub('([\\%*_~`|>])', '\\%1'))
end

-- Wrap text in a code block (backticks inside are swapped so the block can't be closed early).
function Utils.codeBlock(s, max)
    local clean = tostring(s or ''):gsub('`', "'")
    return '```' .. Utils.truncate(clean, max or 1000) .. '```'
end

function Utils.coords(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return 'Unknown' end
    return ('%.1f, %.1f, %.1f'):format(x, y, z)
end

function Utils.duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local h = seconds // 3600
    local m = (seconds % 3600) // 60
    local s = seconds % 60
    if h > 0 then return ('%dh %dm'):format(h, m) end
    if m > 0 then return ('%dm %ds'):format(m, s) end
    return ('%ds'):format(s)
end

function Utils.identifiers(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind, value = id:match('^(%w+):(.+)$')
        if kind and not ids[kind] then
            ids[kind] = value
        end
    end
    return ids
end

-- Cached player info (name, identifiers, join time). Falls back to a live lookup.
function Utils.getPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    if Players and Players[src] then return Players[src] end
    local name = GetPlayerName(src)
    if not name then return nil end
    return { name = name, ids = Utils.identifiers(src) }
end

function Utils.playerName(src)
    local p = Utils.getPlayer(src)
    return p and p.name or ('ID ' .. tostring(src))
end

local ID_ORDER = { 'license', 'fivem', 'steam', 'xbl', 'live', 'ip' }

function Utils.idLines(ids)
    local lines = {}
    if Config.Identifiers.discord and ids.discord then
        lines[#lines + 1] = ('Discord: <@%s>'):format(ids.discord)
    end
    for _, kind in ipairs(ID_ORDER) do
        if Config.Identifiers[kind] and ids[kind] then
            lines[#lines + 1] = ('%s: `%s`'):format(kind, ids[kind])
        end
    end
    return table.concat(lines, '\n')
end

-- A ready-made embed field describing a player.
function Utils.playerField(label, src, inline)
    local p = Utils.getPlayer(src)
    if not p then
        return { name = label, value = ('ID %s (not connected)'):format(tostring(src)), inline = inline }
    end
    local value = ('**%s** (ID %s)'):format(Utils.escape(p.name), tostring(src))
    local ids = Utils.idLines(p.ids or {})
    if ids ~= '' then value = value .. '\n' .. ids end
    return { name = label, value = value, inline = inline }
end

-- ─────────────────────────────── Weapons ───────────────────────────────

local WEAPONS = {
    'WEAPON_UNARMED', 'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_GOLFCLUB',
    'WEAPON_CROWBAR', 'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_MACHETE',
    'WEAPON_SWITCHBLADE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_POOLCUE', 'WEAPON_STONE_HATCHET',
    'WEAPON_FLASHLIGHT', 'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL',
    'WEAPON_STUNGUN', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2', 'WEAPON_HEAVYPISTOL',
    'WEAPON_VINTAGEPISTOL', 'WEAPON_FLAREGUN', 'WEAPON_MARKSMANPISTOL', 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2',
    'WEAPON_DOUBLEACTION', 'WEAPON_CERAMICPISTOL', 'WEAPON_NAVYREVOLVER', 'WEAPON_GADGETPISTOL',
    'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW',
    'WEAPON_MACHINEPISTOL', 'WEAPON_MINISMG', 'WEAPON_GUSENBERG', 'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2',
    'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_HEAVYSHOTGUN',
    'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN', 'WEAPON_COMBATSHOTGUN', 'WEAPON_MUSKET', 'WEAPON_ASSAULTRIFLE',
    'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE',
    'WEAPON_SPECIALCARBINE', 'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2',
    'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE', 'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2',
    'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2', 'WEAPON_MARKSMANRIFLE',
    'WEAPON_MARKSMANRIFLE_MK2', 'WEAPON_RPG', 'WEAPON_GRENADELAUNCHER', 'WEAPON_MINIGUN', 'WEAPON_FIREWORK',
    'WEAPON_RAILGUN', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYPISTOL', 'WEAPON_GRENADE',
    'WEAPON_STICKYBOMB', 'WEAPON_PROXMINE', 'WEAPON_PIPEBOMB', 'WEAPON_MOLOTOV', 'WEAPON_SMOKEGRENADE',
    'WEAPON_BZGAS', 'WEAPON_FLARE', 'WEAPON_SNOWBALL', 'WEAPON_BALL', 'WEAPON_PETROLCAN', 'WEAPON_FIREEXTINGUISHER',
    -- causes of death that aren't real weapons
    'WEAPON_FALL', 'WEAPON_DROWNING', 'WEAPON_DROWNING_IN_VEHICLE', 'WEAPON_RUN_OVER_BY_CAR',
    'WEAPON_RAMMED_BY_CAR', 'WEAPON_EXPLOSION', 'WEAPON_FIRE', 'WEAPON_BLEEDING', 'WEAPON_ANIMAL',
    'WEAPON_COUGAR', 'WEAPON_BARBED_WIRE', 'WEAPON_EXHAUSTION', 'WEAPON_ELECTRIC_FENCE',
    'WEAPON_HIT_BY_WATER_CANNON', 'VEHICLE_WEAPON_ROTORS',
}

local weaponLookup

local function toUnsigned(hash)
    local n = math.tointeger(hash) or math.floor(tonumber(hash) or 0)
    return n & 0xFFFFFFFF
end

local function prettyWeapon(name)
    local s = name:gsub('^VEHICLE_WEAPON_', ''):gsub('^WEAPON_', ''):gsub('_', ' '):lower()
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

function Utils.weaponName(hash)
    if not tonumber(hash) then return 'Unknown' end
    if not weaponLookup then
        weaponLookup = {}
        for _, name in ipairs(WEAPONS) do
            weaponLookup[toUnsigned(GetHashKey(name))] = prettyWeapon(name)
        end
    end
    return weaponLookup[toUnsigned(hash)] or ('Unknown (%s)'):format(tostring(math.tointeger(hash) or hash))
end

-- ─────────────────────────────── Explosions ────────────────────────────

local EXPLOSIONS = {
    [0] = 'Grenade', 'Grenade Launcher', 'Sticky Bomb', 'Molotov', 'Rocket', 'Tank Shell', 'Hi Octane',
    'Car', 'Plane', 'Petrol Pump', 'Bike', 'Steam', 'Flame', 'Water Hydrant', 'Gas Canister', 'Boat',
    'Ship Destroy', 'Truck', 'Bullet', 'Smoke Grenade Launcher', 'Smoke Grenade', 'BZ Gas', 'Flare',
    'Gas Canister 2', 'Extinguisher', 'Programmable AR', 'Train', 'Barrel', 'Propane', 'Blimp',
    'Flame Explode', 'Tanker', 'Plane Rocket', 'Vehicle Bullet', 'Gas Tank', 'Bird Crap', 'Railgun',
    'Blimp 2', 'Firework', 'Snowball', 'Proximity Mine', 'Valkyrie Cannon', 'Air Defence', 'Pipe Bomb',
    'Vehicle Mine', 'Explosive Ammo', 'APC Shell', 'Cluster Bomb', 'Gas Bomb', 'Incendiary Bomb',
    'Standard Bomb', 'Torpedo', 'Underwater Torpedo', 'Bombushka Cannon', 'Cluster Bomb Secondary',
    'Hunter Barrage', 'Hunter Cannon', 'Rogue Cannon', 'Underwater Mine', 'Orbital Cannon',
    'Wide Standard Bomb', 'Explosive Shotgun Ammo', 'Oppressor Mk2 Cannon', 'Kinetic Mortar',
    'Kinetic Vehicle Mine', 'EMP Vehicle Mine', 'Spike Vehicle Mine', 'Slick Vehicle Mine',
    'Tar Vehicle Mine', 'Script Drone', 'Up-n-Atomizer', 'Buried Mine', 'Script Missile',
}

function Utils.explosionName(kind)
    kind = tonumber(kind)
    return kind and EXPLOSIONS[kind] or 'Unknown'
end
