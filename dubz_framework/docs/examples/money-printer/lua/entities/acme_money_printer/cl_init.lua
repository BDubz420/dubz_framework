include("shared.lua")

local CANVAS_WIDTH = 300
local CANVAS_HEIGHT = 304
local PADDING = 14
local BAR_HEIGHT = 12
local BAR_SPACING = 38
local STATE = AcmePrinters.State

local fonts

local function getFonts()
    if fonts then return fonts end

    fonts = {
        title = DFW.UI.CreateFont("printer_title", 26, 800),
        money = DFW.UI.CreateFont("printer_money", 34, 800),
        body = DFW.UI.CreateFont("printer_body", 18, 600),
        small = DFW.UI.CreateFont("printer_small", 15, 500)
    }

    return fonts
end

local function stateColor(theme, state)
    if state == STATE.Printing then return theme.success end
    if state == STATE.Overheated then return theme.danger end
    if state == STATE.NoInk then return theme.warning end
    if state == STATE.Full then return theme.accent end

    return theme.textMuted
end

local function drawBar(theme, fonts, x, y, width, label, fraction, color, value)
    DFW.Draw.Text(label, fonts.small, x, y, theme.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DFW.Draw.Text(value, fonts.small, x + width, y, theme.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    DFW.Draw.Bar(x, y + 18, width, BAR_HEIGHT, fraction, color)
end

local function percent(value, maximum)
    return math.Clamp(value / math.max(maximum, 1), 0, 1)
end

local function drawHeader(theme, fonts, printer, left, width, top)
    local owner = printer:Getowning_ent()
    local ownerName = IsValid(owner) and owner:Nick() or AcmePrinters.Phrase("Unowned")

    DFW.Draw.Text(AcmePrinters.Config.Name, fonts.title, left, top + 22, theme.text)
    DFW.Draw.Text(ownerName, fonts.small, left + width, top + 24, theme.textMuted, TEXT_ALIGN_RIGHT)
end

local function drawMoney(theme, fonts, printer, top)
    local config = AcmePrinters.Config

    DFW.Draw.Text(AcmePrinters.Adapter.FormatMoney(printer:GetStored()), fonts.money, 0, top + 66, theme.accent, TEXT_ALIGN_CENTER)
    DFW.Draw.Text("of " .. AcmePrinters.Adapter.FormatMoney(config.StoreMax), fonts.small, 0, top + 92, theme.textMuted, TEXT_ALIGN_CENTER)
end

local function drawBars(theme, fonts, printer, left, width, top)
    local config = AcmePrinters.Config
    local state = printer:GetState()
    local remaining = math.max(printer:GetNextPrint() - CurTime(), 0)
    local band = AcmePrinters.HeatBand(printer:GetHeat())
    local integrity = percent(printer:GetIntegrity(), config.Health)
    local y = top + 112

    local printFraction = state == STATE.Printing and 1 - percent(remaining, config.PrintSeconds) or 0
    local printValue = state == STATE.Printing and math.ceil(remaining) .. "s" or "-"

    drawBar(theme, fonts, left, y, width, "Next print", printFraction, theme.accent, printValue)
    drawBar(theme, fonts, left, y + BAR_SPACING, width, "Ink", percent(printer:GetInk(), config.InkMax), theme.info, math.floor(printer:GetInk()) .. "%")
    drawBar(theme, fonts, left, y + BAR_SPACING * 2, width, "Heat", percent(printer:GetHeat(), 100), band.Color, band.Label)
    drawBar(theme, fonts, left, y + BAR_SPACING * 3, width, "Health", integrity, DFW.Anim.Color(theme.danger, theme.success, integrity), math.floor(integrity * 100) .. "%")
end

local function drawFooter(theme, fonts, printer, top)
    local state = printer:GetState()
    local bottom = top + CANVAS_HEIGHT

    DFW.Draw.Text(AcmePrinters.StateName(state), fonts.body, 0, bottom - 38, stateColor(theme, state), TEXT_ALIGN_CENTER)
    DFW.Draw.Text(AcmePrinters.Phrase("Hint"), fonts.small, 0, bottom - 16, theme.textDim, TEXT_ALIGN_CENTER)
end

local function drawScreen(printer)
    local theme = DFW.UI.GetTheme()
    local fonts = getFonts()
    local top = -CANVAS_HEIGHT / 2
    local left = -CANVAS_WIDTH / 2 + PADDING
    local width = CANVAS_WIDTH - PADDING * 2

    DFW.Draw.Card(-CANVAS_WIDTH / 2, top, CANVAS_WIDTH, CANVAS_HEIGHT, {radius = "MD", color = theme.background})
    drawHeader(theme, fonts, printer, left, width, top)
    drawMoney(theme, fonts, printer, top)
    drawBars(theme, fonts, printer, left, width, top)
    drawFooter(theme, fonts, printer, top)
end

local current

local function paintCurrent()
    drawScreen(current)
end

function ENT:Draw()
    self:DrawModel()

    if not (DFW and DFW.UI) then return end

    local config = AcmePrinters.Config
    local angle = self:GetAngles()

    angle:RotateAroundAxis(angle:Up(), config.ScreenYaw)

    current = self
    DFW.Draw.World(self:GetPos() + self:GetUp() * config.ScreenUp, angle, config.ScreenScale, config.ScreenDistance, paintCurrent)
end
