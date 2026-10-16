-- Add these to qb-core/shared/items.lua (inside QBShared.Items) when you use qb-inventory.
-- With ox_inventory on QBCore, use items/ox_inventory.lua instead.
-- Used by force_drugs (reward) and force_drugsell (what the dealers buy). One item = 1 gram.
-- qb-core already ships an item named 'meth'; keep yours, the line below only matches it.

coke = { name = 'coke', label = 'Cocaine', weight = 1, type = 'item', image = 'cokebaggy.png', unique = false, useable = false, shouldClose = true, description = 'A gram of cocaine' },
meth = { name = 'meth', label = 'Meth', weight = 1, type = 'item', image = 'meth_baggy.png', unique = false, useable = false, shouldClose = true, description = 'A gram of meth' },
weed = { name = 'weed', label = 'Weed', weight = 1, type = 'item', image = 'weed_baggy.png', unique = false, useable = false, shouldClose = true, description = 'A gram of weed' },
