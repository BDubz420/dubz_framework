AcmePrinters.Adapter = AcmePrinters.Adapter or {}

local adapter = AcmePrinters.Adapter

function adapter.FormatMoney(amount)
    local custom = hook.Run("AcmePrintersFormatMoney", amount)

    if custom then return custom end
    if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(amount) end

    return "$" .. string.Comma(amount)
end

function adapter.CanAfford(ply, amount)
    local custom = hook.Run("AcmePrintersCanAfford", ply, amount)

    if custom ~= nil then return custom == true end
    if ply.canAfford then return ply:canAfford(amount) end

    return false
end

function adapter.AddMoney(ply, amount)
    if hook.Run("AcmePrintersAddMoney", ply, amount) == true then return end

    if ply.addMoney then ply:addMoney(amount) end
end

function adapter.Notify(ply, text, kind)
    if not IsValid(ply) then return end

    if hook.Run("AcmePrintersNotify", ply, text, kind) == true then return end

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, kind or 0, 4, text)
    else
        ply:ChatPrint(text)
    end
end

hook.Add("loadCustomDarkRPItems", "AcmePrinters_Items", function()
    local config = AcmePrinters.Config

    if not (DarkRP and DarkRP.createCategory and DarkRP.createEntity) then return end

    DarkRP.createCategory{
        name = config.Category,
        categorises = "entities",
        startExpanded = true,
        color = config.CategoryColor,
        sortOrder = 20,
        canSee = function() return true end
    }

    local items = {
        {name = config.Name, ent = "acme_money_printer", model = config.Model, price = config.Price, max = config.MaxPerPlayer, cmd = config.Command},
        {name = config.BottleName, ent = "acme_ink_bottle", model = config.BottleModel, price = config.BottlePrice, max = config.BottleMax, cmd = config.BottleCommand},
        {name = config.CoolantName, ent = "acme_coolant_module", model = config.CoolantModel, price = config.CoolantPrice, max = config.CoolantMax, cmd = config.CoolantCommand}
    }

    for _, item in ipairs(items) do
        DarkRP.createEntity(item.name, {
            ent = item.ent,
            model = item.model,
            price = item.price,
            max = item.max,
            cmd = item.cmd,
            category = config.Category
        })
    end
end)
