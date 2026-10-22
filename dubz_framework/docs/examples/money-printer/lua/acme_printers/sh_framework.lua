local config = AcmePrinters.Config

local specs = {
    {path = "Name", label = "Display Name", group = "Shop", maxLength = 40,
        description = "Shown in the shop menu and on the printer's screen."},
    {path = "Category", label = "Shop Category", group = "Shop", maxLength = 40,
        description = "Changes need a restart to reach the shop menu."},
    {path = "CategoryColor", label = "Shop Category Colour", group = "Shop",
        description = "Changes need a restart to reach the shop menu."},
    {path = "SpawnCategory", label = "Spawn Menu Category", group = "Shop", maxLength = 40,
        description = "Changes need a restart to reach the spawn menu."},
    {path = "Command", label = "Buy Command", group = "Shop", maxLength = 30,
        description = "Lowercase, no spaces. Changes need a restart to reach the shop menu."},
    {path = "Model", label = "Model", group = "Shop", maxLength = 120,
        description = "Changes need a restart. A different model needs the screen dialled in again."},
    {path = "Price", label = "Price", min = 0, max = 1000000, decimals = 0, group = "Shop",
        description = "Changes need a restart to reach the shop menu."},
    {path = "MaxPerPlayer", label = "Most Per Player", min = 1, max = 50, decimals = 0, group = "Shop",
        description = "Changes need a restart to reach the shop menu."},
    {path = "SeizeReward", label = "Seize Reward", min = 0, max = 100000, decimals = 0, group = "Shop",
        description = "What enforcement earns for seizing a printer. Applies to printers spawned after the change."},

    {path = "BottleName", label = "Name", group = "Ink Bottle", maxLength = 40},
    {path = "BottleModel", label = "Model", group = "Ink Bottle", maxLength = 120,
        description = "Changes need a restart."},
    {path = "BottleCommand", label = "Buy Command", group = "Ink Bottle", maxLength = 30,
        description = "Changes need a restart to reach the shop menu."},
    {path = "BottlePrice", label = "Price", min = 0, max = 100000, decimals = 0, group = "Ink Bottle",
        description = "Changes need a restart to reach the shop menu."},
    {path = "BottleMax", label = "Most Per Player", min = 1, max = 50, decimals = 0, group = "Ink Bottle",
        description = "Changes need a restart to reach the shop menu."},
    {path = "InkPerBottle", label = "Ink Per Bottle", min = 1, max = 1000, decimals = 0, group = "Ink Bottle",
        description = "Touch a bottle to a printer to pour it in."},

    {path = "CoolantName", label = "Name", group = "Coolant Module", maxLength = 40},
    {path = "CoolantModel", label = "Model", group = "Coolant Module", maxLength = 120,
        description = "Changes need a restart."},
    {path = "CoolantCommand", label = "Buy Command", group = "Coolant Module", maxLength = 30,
        description = "Changes need a restart to reach the shop menu."},
    {path = "CoolantPrice", label = "Price", min = 0, max = 100000, decimals = 0, group = "Coolant Module",
        description = "Changes need a restart to reach the shop menu."},
    {path = "CoolantMax", label = "Most Per Player", min = 1, max = 50, decimals = 0, group = "Coolant Module",
        description = "Changes need a restart to reach the shop menu."},
    {path = "CoolantMode", label = "Mode", choices = {"install", "consume"}, group = "Coolant Module",
        description = "Install: the module attaches to the printer and cools it for good. Consume: it is used up and removes heat once."},
    {path = "CoolantHeatDrop", label = "Heat Removed (Consume Mode)", min = 1, max = 100, decimals = 0, group = "Coolant Module"},
    {path = "CoolerSlots", label = "Slots Per Printer (Install Mode)", min = 1, max = 8, decimals = 0, group = "Coolant Module"},
    {path = "CoolerPerSecond", label = "Cooling Per Module (Per Second)", min = 0, max = 20, decimals = 2, group = "Coolant Module"},

    {path = "PrintSeconds", label = "Seconds Per Print", min = 1, max = 3600, decimals = 0, group = "Printing"},
    {path = "PrintAmount", label = "Money Per Print", min = 1, max = 100000, decimals = 0, group = "Printing"},
    {path = "StoreMax", label = "Store Capacity", min = 100, max = 10000000, decimals = 0, group = "Printing",
        description = "A printer stops when its store is full, until the owner collects."},

    {path = "InkMax", label = "Ink Capacity", min = 10, max = 1000, decimals = 0, group = "Ink"},
    {path = "InkPerPrint", label = "Ink Per Print", min = 0, max = 100, decimals = 1, group = "Ink"},

    {path = "HeatPerPrint", label = "Heat Per Print", min = 0, max = 100, decimals = 1, group = "Cooling"},
    {path = "CoolPerSecond", label = "Passive Cooling Per Second", min = 0, max = 20, decimals = 2, group = "Cooling"},
    {path = "CriticalHeat", label = "Danger Heat", min = 10, max = 100, decimals = 0, group = "Cooling",
        description = "At or above this heat the printer may explode. Keep it below the shutdown heat, or a printer can never explode."},
    {path = "ShutdownHeat", label = "Shutdown Heat", min = 10, max = 100, decimals = 0, group = "Cooling",
        description = "The printer stops printing at this heat."},
    {path = "ResumeHeat", label = "Resume Heat", min = 0, max = 99, decimals = 0, group = "Cooling",
        description = "A shut down printer starts again when it cools to this heat."},
    {path = "ExplodeChance", label = "Explosion Chance In Danger (% Per Second)", min = 0, max = 100, decimals = 1, group = "Cooling"},

    {path = "Health", label = "Printer Health", min = 10, max = 1000, decimals = 0, group = "Damage",
        description = "Applies to printers spawned after the change."},
    {path = "ExplosionRadius", label = "Explosion Radius (Units)", min = 20, max = 1000, decimals = 0, group = "Damage"},
    {path = "ExplosionDamage", label = "Explosion Damage", min = 0, max = 500, decimals = 0, group = "Damage"},

    {path = "CoolerOffsetX", label = "Module: Forward", min = -100, max = 100, decimals = 1, group = "Dial In: Cooling Modules",
        description = "Where the first installed module sits, in the printer's own space: forward, left, up."},
    {path = "CoolerOffsetY", label = "Module: Left", min = -100, max = 100, decimals = 1, group = "Dial In: Cooling Modules"},
    {path = "CoolerOffsetZ", label = "Module: Up", min = -100, max = 100, decimals = 1, group = "Dial In: Cooling Modules"},
    {path = "CoolerSpacing", label = "Module: Spacing", min = 0, max = 100, decimals = 1, group = "Dial In: Cooling Modules",
        description = "Distance between installed modules, to the left of the first."},

    {path = "ScreenDistance", label = "Screen Visible Within (Units)", min = 50, max = 2000, decimals = 0, group = "Dial In: Screen"},
    {path = "ScreenUp", label = "Screen: Up", min = -50, max = 100, decimals = 1, group = "Dial In: Screen"},
    {path = "ScreenScale", label = "Screen: Size", min = 0.02, max = 0.5, decimals = 3, group = "Dial In: Screen"},
    {path = "ScreenYaw", label = "Screen: Turn", min = -180, max = 180, decimals = 0, group = "Dial In: Screen"},

    {path = "Sound", label = "Printer Sound", group = "Sound"},
    {path = "LoopSound", label = "Running Sound", group = "Sound", maxLength = 120},
    {path = "SoundLevel", label = "Sound Radius", min = 30, max = 100, decimals = 0, group = "Sound"},
    {path = "FillSound", label = "Ink Poured Sound", group = "Sound", maxLength = 120},
    {path = "InstallSound", label = "Module Installed Sound", group = "Sound", maxLength = 120}
}

for key in SortedPairs(config.Text) do
    specs[#specs + 1] = {path = "Text." .. key, label = "Text: " .. key, group = "Text", maxLength = 120}
end

DFW.Bind.Module({
    id = "printers",
    name = "Money Printers",
    version = "1.0.0",
    icon = "economy/payments",
    description = "Printers, ink bottles, coolant modules, heat, damage and the on-screen display.",
    dependencies = {"dubz_core"}
}, config, specs, {
    OnChange = function(path)
        if SERVER and AcmePrinters.QueueLayout and string.StartWith(path, "Cooler") then AcmePrinters.QueueLayout() end
    end,
    collections = {
        {
            id = "heat_bands",
            label = "Heat Bands",
            description = "The names and colours shown for a printer's heat. Each row starts at its heat and lasts until the next one.",
            preview = {kind = "chip", text = "label", color = "color"},
            columns = {
                {key = "heat", label = "From Heat", type = "number", min = 0, max = 100, decimals = 0, width = 1},
                {key = "label", label = "Label", type = "string", maxLength = 24, width = 2},
                {key = "color", label = "Colour", type = "color", width = 1}
            },
            default = AcmePrinters.DefaultHeatBands
        }
    }
})

DFW.Collections.Watch("printers", "heat_bands", AcmePrinters.BuildHeatBands)
