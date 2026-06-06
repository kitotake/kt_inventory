fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'kt_inventory'
author 'kitotake'
version '2.44.1'
repository 'https://github.com/kitotake/kt_inventory'
description 'Slot-based inventory with item metadata support'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'kt_lib',
}

shared_script '@kt_lib/init.lua'

kt_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua',
    'modules/bridge/union/trash/server_union.lua',
    'modules/bridge/union/clothing_server.lua',  -- ← à ajouter
}

client_scripts {
    'init.lua',
    'modules/bridge/union/preview.lua',
    'modules/bridge/union/trash/client_union.lua',
    'modules/bridge/union/clothing_client.lua'
}

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/images/**',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'data/*.lua',
}