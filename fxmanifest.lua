fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'anti_logger'
author 'Antidothe | Antizone'
description 'Standalone Discord logger: joins, leaves, chat, deaths, explosions, commands, admin/menu actions and txAdmin events'
version '1.0.0'

-- config.lua is server-only on purpose: it holds your webhook URLs,
-- and anything in shared/client scripts is downloaded by every player.
server_scripts {
    'config.lua',
    'server/utils.lua',
    'server/discord.lua',
    'server/main.lua',
    'server/txadmin.lua',
}

client_script 'client/main.lua'
