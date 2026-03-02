fx_version 'cerulean'
game 'gta5'

author 'sBanking'
description 'Système bancaire ESX avec UI HTML'
version '1.0.0'
discord 'https://discord.gg/PxN5xMBbGY'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}