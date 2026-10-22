local TIMER_NAME = "AcmePrinters_Layout"
local SETTLE_SECONDS = 0.4

function AcmePrinters.ApplyLayout()
    for _, printer in ipairs(ents.FindByClass("acme_money_printer")) do
        printer:LayoutCoolers()
    end
end

function AcmePrinters.QueueLayout()
    timer.Create(TIMER_NAME, SETTLE_SECONDS, 1, AcmePrinters.ApplyLayout)
end
