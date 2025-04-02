fx_version 'cerulean'
game 'gta5'

author 'Noam Shoshan'

lua54 'yes'

client_script 'client/client.lua'

shared_scripts {
    'shared/shared.lua',
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}

server_script 'server/server.lua'

escrow_ignore {
    "server/server.lua",
    "shared/shared.lua"
}
dependency '/assetpacks'