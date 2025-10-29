Config = {}

-- 🔑 Key to activate powers
Config.PowerKey = 38 -- E key

-- ⚡ Define ped powers here
Config.SuperPeds = {
    { model = "noob1", power = "telekinesis" },
    { model = "MEPHISTO", power = "shockwave" },
    { model = "veggiebaobros", power = "teleport" },
    { model = "daedricarmor", power = "superkick" },
    { model = "LikulaoGyee", power = "thor" },
}

-- 💥 Power tuning
Config.KickForce = 300.0
Config.kickRadius = 5
Config.ShockwaveForce = 150.0
Config.ShockwaveRadius = 25.0
Config.TeleportLimit = 100.0

Config.TelekinesisRange = 50.0
Config.LiftForce = 10.0
Config.LiftHeight = 5.0
Config.LiftTime = 2000
Config.DropForce = -20.0

Config.ThorRadius = 60.0
Config.ThorForce = 60.0