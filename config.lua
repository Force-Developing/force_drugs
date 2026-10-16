Config = {}

-- Prints extra info to the F8 / server console. Setup errors are always printed.
Config.Debug = false

-- "en", "sv" or "auto" (follows the replicated ox:locale convar: setr ox:locale "sv")
Config.Locale = "en"

-- "auto" (detected by the server: qbx_core, es_extended, qb-core), "esx", "qb", "qbx" or "custom"
Config.Framework = "auto"

-- "auto" (ox_target, then qb-target, else [E] + text UI), "ox_target", "qb-target" or "none" ([E] + text UI)
Config.Target = "auto"

-- The man who hands out the jobs and takes the crates back
Config.Boss = {
    name = "Kalle",                         -- shown in the menu, the prompt and the map blip
    model = "g_m_m_armgoon_01",
    coords = vec4(1020.58, -1733.34, 34.62, 270.0),
    anim = { dict = "mini@strip_club@idles@bouncer@base", clip = "base" }, -- false for none
    blip = false,                           -- { sprite = 51, colour = 1, scale = 0.7 } to show him on the map
}

-- How close (meters) the player has to stand to the boss and to a crate. The server allows a small margin on top.
Config.InteractDistance = 2.0

-- Police needed online to start a job. 0 = no requirement.
Config.Police = {
    jobs = { "police", "sheriff" },
    minimum = 0,
    onlyOnDuty = true, -- QBCore / QBox duty, ESX job.onDuty where your ESX version has it
}

-- Seconds it takes to pick up one crate
Config.PickupDuration = 10

-- Draw the time left and the crate count at the top of the screen during a job
Config.ShowTimer = true

--[[
  The jobs. The key is the job id; the menu lists them by key.
  label         = menu label
  item          = item given as the reward (must exist in your inventory, see the items folder)
  amount        = { min, max } items given when the crates are delivered
  timeLimit     = seconds to collect the crates and get back to the boss
  cooldown      = seconds before the same player can take this job again (after a delivery, a failure or death)
  cratesNeeded  = crates to collect (out of all crates listed)
  area          = { coords, radius } shown on the map; crates and guards appear when the player gets close
  crates        = { model, coords } where the crates stand
  guards        = hostile NPCs around the crates: { model, weapon, coords = vec4 }
]]
Config.Missions = {
    coke = {
        label = "Cocaine",
        item = "coke",
        amount = { min = 5, max = 10 },
        timeLimit = 1000,
        cooldown = 480,
        cratesNeeded = 7,
        area = { coords = vec3(1571.91, 3585.04, 35.36), radius = 50.0 },
        crates = {
            { model = "prop_cs_cardbox_01", coords = vec3(1567.86, 3577.27, 32.16) },
            { model = "prop_cs_rub_box_01", coords = vec3(1542.03, 3575.89, 34.45) },
            { model = "prop_cardbordbox_03a", coords = vec3(1541.28, 3596.49, 34.47) },
            { model = "prop_cardbordbox_04a", coords = vec3(1560.86, 3596.75, 37.79) },
            { model = "prop_cardbordbox_04a", coords = vec3(1537.22, 3594.38, 37.78) },
            { model = "prop_cardbordbox_03a", coords = vec3(1510.41, 3567.99, 41.13) },
            { model = "prop_cs_cardbox_01", coords = vec3(1569.58, 3567.65, 34.45) },
            { model = "prop_cs_cardbox_01", coords = vec3(1608.50, 3578.81, 34.45) },
            { model = "prop_cs_rub_box_01", coords = vec3(1589.29, 3592.76, 41.13) },
            { model = "prop_cs_cardbox_01", coords = vec3(1599.08, 3569.15, 34.42) },
        },
        guards = {
            { model = "a_m_y_methhead_01", weapon = "WEAPON_BAT", coords = vec4(1536.11, 3593.48, 38.77, 210.0) },
            { model = "a_m_y_mexthug_01", weapon = "WEAPON_KNUCKLE", coords = vec4(1572.37, 3571.19, 35.44, 40.0) },
            { model = "u_m_m_edtoh", weapon = "WEAPON_KNIFE", coords = vec4(1599.85, 3590.29, 38.77, 120.0) },
        },
    },
    meth = {
        label = "Meth",
        item = "meth",
        amount = { min = 5, max = 15 },
        timeLimit = 1250,
        cooldown = 480,
        cratesNeeded = 7,
        area = { coords = vec3(287.74, 2860.55, 43.64), radius = 50.0 },
        crates = {
            { model = "prop_cs_cardbox_01", coords = vec3(265.03, 2871.19, 42.63) },
            { model = "prop_cs_rub_box_01", coords = vec3(287.67, 2823.39, 43.99) },
            { model = "prop_cardbordbox_03a", coords = vec3(255.30, 2875.30, 42.61) },
            { model = "prop_cardbordbox_04a", coords = vec3(286.43, 2841.22, 42.66) },
            { model = "prop_cardbordbox_04a", coords = vec3(271.94, 2859.01, 42.66) },
            { model = "prop_cardbordbox_04a", coords = vec3(272.03, 2865.77, 73.19) },
            { model = "prop_cardbordbox_03a", coords = vec3(311.01, 2861.18, 42.55) },
            { model = "prop_cardbordbox_03a", coords = vec3(322.33, 2877.88, 42.46) },
            { model = "prop_cs_rub_box_01", coords = vec3(318.81, 2884.07, 45.40) },
            { model = "prop_cs_cardbox_01", coords = vec3(314.10, 2887.05, 48.59) },
        },
        guards = {
            { model = "a_m_y_mexthug_01", weapon = "WEAPON_KNIFE", coords = vec4(296.18, 2879.47, 43.61, 210.0) },
            { model = "u_m_m_edtoh", weapon = "WEAPON_KNUCKLE", coords = vec4(287.10, 2843.89, 44.70, 30.0) },
            { model = "a_m_y_methhead_01", weapon = "WEAPON_BAT", coords = vec4(314.84, 2862.53, 43.52, 50.0) },
        },
    },
    weed = {
        label = "Weed",
        item = "weed",
        amount = { min = 5, max = 25 },
        timeLimit = 750,
        cooldown = 480,
        cratesNeeded = 7,
        area = { coords = vec3(-3169.79, 1101.08, 20.76), radius = 50.0 },
        crates = {
            { model = "prop_cs_cardbox_01", coords = vec3(-3167.86, 1098.45, 19.87) },
            { model = "prop_cs_rub_box_01", coords = vec3(-3163.09, 1112.50, 19.83) },
            { model = "prop_cardbordbox_03a", coords = vec3(-3181.21, 1074.41, 24.50) },
            { model = "prop_cardbordbox_04a", coords = vec3(-3182.58, 1110.54, 20.08) },
            { model = "prop_cardbordbox_04a", coords = vec3(-3155.11, 1104.17, 19.88) },
            { model = "prop_cardbordbox_03a", coords = vec3(-3147.87, 1119.24, 19.88) },
            { model = "prop_cs_rub_box_01", coords = vec3(-3158.76, 1091.67, 19.87) },
            { model = "prop_cardbordbox_03a", coords = vec3(-3162.42, 1125.96, 19.92) },
            { model = "prop_cardbordbox_03a", coords = vec3(-3163.70, 1102.28, 23.38) },
            { model = "prop_cs_cardbox_01", coords = vec3(-3190.40, 1085.67, 19.89) },
        },
        guards = {
            { model = "a_m_y_mexthug_01", weapon = "WEAPON_KNUCKLE", coords = vec4(-3166.53, 1102.78, 20.82, 323.0) },
            { model = "u_m_m_edtoh", weapon = "WEAPON_BAT", coords = vec4(-3164.41, 1111.64, 20.79, 181.0) },
            { model = "a_m_y_methhead_01", weapon = "WEAPON_KNIFE", coords = vec4(-3154.74, 1099.88, 20.85, 250.0) },
        },
    },
}
