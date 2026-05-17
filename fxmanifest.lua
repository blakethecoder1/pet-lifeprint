fx_version 'cerulean'
game 'gta5'

author 'PET Development (concept) · Built with BLDR'
description 'Lifeprint — The City Remembers · Character memory, relationship, reputation, and rumor system for FiveM RP'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/bridge.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/brain-hud.png'
}

-- NUI callback for loading external images
nui_callback 'https://*' -- Allow loading external HTTPS images (DiceBear, etc.)

dependencies {
    '/server:5181',
    'oxmysql'
}
