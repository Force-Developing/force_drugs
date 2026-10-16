fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'force_drugs'
author 'Force Developments <discord:@force3883>'
description 'Drug pickup missions: collect crates guarded by hostile NPCs and bring them back for coke, meth or weed. ESX, QBCore and QBox.'
version '2.0.0'

dependencies {
    '/onesync',
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/functions.lua',
}

server_scripts {
    'version.lua',
    'server/custom/frameworks/*.lua',
    'server/custom/inventory.lua',
    'server/main.lua',
}

client_scripts {
    'client/custom/frameworks/*.lua',
    'client/interact.lua',
    'client/main.lua',
}

files {
    'locales/*.json',
}
