

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'michalxdl'

client_scripts { 
    'config.lua',
    'client/spheres.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

ui_page 'client/html/index.html'

files {
    "client/html/index.html",
    "client/html/script.js",
    "client/html/style.css"
}
