-- Add these to ox_inventory/data/items.lua (inside the returned table).
-- Used by force_drugs (reward) and force_drugsell (what the dealers buy). One item = 1 gram.

['coke'] = {
    label = 'Cocaine',
    weight = 1,
    stack = true,
    close = true,
    description = 'A gram of cocaine',
},

['meth'] = {
    label = 'Meth',
    weight = 1,
    stack = true,
    close = true,
    description = 'A gram of meth',
},

['weed'] = {
    label = 'Weed',
    weight = 1,
    stack = true,
    close = true,
    description = 'A gram of weed',
},
