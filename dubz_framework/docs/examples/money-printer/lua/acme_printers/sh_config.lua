AcmePrinters.Config = {
    Name = "Money Printer",
    Category = "Printers",
    SpawnCategory = "Acme Printers",
    CategoryColor = Color(35, 35, 35),
    Command = "buymoneyprinter",
    Model = "models/props_c17/consolebox01a.mdl",
    Price = 1500,
    MaxPerPlayer = 2,
    SeizeReward = 600,

    BottleName = "Ink Bottle",
    BottleModel = "models/props_lab/jar01b.mdl",
    BottleCommand = "buyinkbottle",
    BottlePrice = 120,
    BottleMax = 6,
    InkPerBottle = 50,

    CoolantName = "Coolant Module",
    CoolantModel = "models/items/battery.mdl",
    CoolantCommand = "buycoolantmodule",
    CoolantPrice = 250,
    CoolantMax = 4,
    CoolantMode = "install",
    CoolantHeatDrop = 40,
    CoolerSlots = 2,
    CoolerPerSecond = 0.35,
    CoolerOffsetX = 0,
    CoolerOffsetY = -8,
    CoolerOffsetZ = 12,
    CoolerSpacing = 14,

    PrintSeconds = 30,
    PrintAmount = 125,
    StoreMax = 5000,

    InkMax = 100,
    InkPerPrint = 4,

    HeatPerPrint = 12,
    CoolPerSecond = 0.3,
    CriticalHeat = 75,
    ShutdownHeat = 90,
    ResumeHeat = 50,
    ExplodeChance = 1,

    Health = 100,
    ExplosionRadius = 160,
    ExplosionDamage = 90,

    ScreenDistance = 280,
    ScreenUp = 11.5,
    ScreenScale = 0.08,
    ScreenYaw = 90,

    Sound = true,
    LoopSound = "ambient/levels/labs/equipment_printer_loop1.wav",
    SoundLevel = 52,
    FillSound = "ambient/water/water_splash1.wav",
    InstallSound = "buttons/button9.wav",

    Text = {
        Collected = "Collected {amount}.",
        NothingToCollect = "Nothing to collect.",
        InkAdded = "The ink tank is topped up.",
        InkFull = "The ink tank is full.",
        CoolerInstalled = "Cooling module installed.",
        CoolerFull = "There is no free cooling slot.",
        Cooled = "Coolant poured in.",
        AlreadyCool = "It is already cool.",
        Exploded = "Your {name} exploded.",
        Unowned = "Unowned",
        Hint = "E collect   Touch it with supplies",
        StateIdle = "Idle",
        StatePrinting = "Printing",
        StateOverheated = "Overheated",
        StateNoInk = "Out of ink",
        StateFull = "Store full"
    }
}

AcmePrinters.State = {
    Idle = 0,
    Printing = 1,
    Overheated = 2,
    NoInk = 3,
    Full = 4
}

AcmePrinters.StateKeys = {
    [AcmePrinters.State.Idle] = "StateIdle",
    [AcmePrinters.State.Printing] = "StatePrinting",
    [AcmePrinters.State.Overheated] = "StateOverheated",
    [AcmePrinters.State.NoInk] = "StateNoInk",
    [AcmePrinters.State.Full] = "StateFull"
}

AcmePrinters.DefaultHeatBands = {
    {heat = 0, label = "Cool", color = {r = 91, g = 201, b = 121, a = 255}},
    {heat = 35, label = "Warm", color = {r = 238, g = 190, b = 80, a = 255}},
    {heat = 55, label = "Hot", color = {r = 238, g = 130, b = 80, a = 255}},
    {heat = 75, label = "Danger", color = {r = 232, g = 84, b = 84, a = 255}}
}

local function toColor(value)
    return Color(value.r or 255, value.g or 255, value.b or 255, value.a or 255)
end

function AcmePrinters.Phrase(key, values)
    local text = AcmePrinters.Config.Text[key] or key

    for name, value in pairs(values or {}) do
        text = string.Replace(text, "{" .. name .. "}", tostring(value))
    end

    return text
end

function AcmePrinters.StateName(state)
    return AcmePrinters.Phrase(AcmePrinters.StateKeys[state] or "StateIdle")
end

function AcmePrinters.BuildHeatBands(rows)
    local source = #rows > 0 and rows or AcmePrinters.DefaultHeatBands
    local bands = {}

    for _, row in ipairs(source) do
        bands[#bands + 1] = {Heat = row.heat, Label = row.label, Color = toColor(row.color)}
    end

    table.sort(bands, function(a, b) return a.Heat < b.Heat end)
    AcmePrinters.HeatBands = bands
end

function AcmePrinters.HeatBand(heat)
    local chosen = AcmePrinters.HeatBands[1]

    for _, band in ipairs(AcmePrinters.HeatBands) do
        if heat >= band.Heat then chosen = band end
    end

    return chosen
end

function AcmePrinters.Enabled()
    return not (DFW and DFW.Bind) or DFW.Bind.Enabled("printers")
end

AcmePrinters.BuildHeatBands(AcmePrinters.DefaultHeatBands)
