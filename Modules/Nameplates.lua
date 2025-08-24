local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local ACR = LibStub("AceConfigRegistry-3.0")
local NP = DRT:NewModule("NP", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")
local drCategories = DRList:GetCategories()
drCategories["taunt"] = nil -- Exclude taunts from DR categories

function NP:OnInitialize()

end


function NP:OnEnable()
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    self.nameplateUnits = self.nameplatUnits or {}
    self.unitContainers = self.unitContainers or {}
    self.categoryFrames = self.categoryFrames or {}
end


function NP:OnDisable()

end


function NP:OnProfileChanged()

end


function NP:SetupDB()
    self.db = DRT.db:RegisterNamespace("NP", {
        profile = {
            -- Settings here
        }
    })
end


function NP:NAME_PLATE_UNIT_ADDED(_, nameplateUnit)
    local unitGUID = UnitGUID(nameplateUnit)
    local nameplateFrame = C_NamePlate.GetNamePlateForUnit(nameplateUnit)

    if not unitGUID or not nameplateFrame then return end

    -- Create DR frames for nameplates if they don't exist yet
    if not self.unitContainers[nameplateUnit] then
        self:CreateFrames(nameplateUnit, nameplateFrame)
        self.unitContainers[nameplateUnit].unitGUID = unitGUID
    end

    -- Refresh DR frames for nameplates if they are reused
    if self.unitContainers[nameplateUnit].unitGUID ~= unitGUID then
        self:UpdateFrames()
        self.unitContainers[nameplateUnit].unitGUID = unitGUID
    end
end


function NP:NAME_PLATE_UNIT_REMOVED(_, nameplateUnit)
    local unitGUID = UnitGUID(nameplateUnit)
    local nameplateFrame = C_NamePlate.GetNamePlateForUnit(nameplateUnit)

    if not nameplateFrame then return end

end


function NP:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()

    if eventType == "SPELL_AURA_APPLIED" then
        -- Use DRList:ContainsCC(spellId) to check if this is a relevant DR spell
        -- Then attach cooldown to nameplate associated with destGUID
    end
end


function NP:CreateFrames(nameplateUnit, nameplateFrame)
    print("CreateFrame" .. nameplateUnit)
    -- Create the container frame and store the reference
    local container = CreateFrame("Frame", "NPContainer." .. nameplateUnit, nameplateFrame)
    self.unitContainers[nameplateUnit] = container

    -- Create the container texture, make it cover the container frame and make it appear under the text label
    container.texture = container:CreateTexture(nil, "OVERLAY")
    container.texture:SetAllPoints()
    container.texture:SetDrawLayer("OVERLAY", 1)

    -- Create the container text label, center it on the container frame and make it appear above the text label
    container.text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.text:SetPoint("CENTER", container, "CENTER", 0, 0)
    container.text:SetDrawLayer("OVERLAY", 2)

    for drCategory, _ in pairs(drCategories) do
        -- Create the DR category frame, center it on the container frame and store the reference
        local frame = CreateFrame("Frame", "NPFrame." .. nameplateUnit .. "." .. drCategory, container)
        frame:SetPoint("CENTER", nameplateFrame, "CENTER", 0, 0)
        self.categoryFrames[nameplateUnit] = self.categoryFrames[nameplateUnit] or {}
        self.categoryFrames[nameplateUnit][drCategory] = frame

        -- Create the icon texture and make it cover the category frame
        frame.icon = frame:CreateTexture(nil, "BACKGROUND")
        frame.icon:SetAllPoints()

        -- Create the cooldown spiral and make it cover the category frame
        frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        frame.cooldown:SetAllPoints()
    end

    self:StyleFrames()
end



function NP:StyleFrames()
    for nameplateUnit, _ in pairs(self.unitContainers) do
        local container = self.unitContainers[nameplateUnit]

        for drCategory, _ in pairs(drCategories) do
            local frame = self.categoryFrames[nameplateUnit][drCategory]

            frame:SetSize(24, 24)

            frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            frame.cooldown:SetDrawEdge(true)
            frame.cooldown:SetDrawSwipe(true)
            frame.cooldown:SetSwipeColor(0, 0, 0, 0.75)
        end
    end
end


function NP:UpdateFrames()
    print("UpdateFrames")
end


function NP:ResetModule()
    self.db:ResetProfile()
end


function NP:GetOptions()
    if not self.db then
        self:SetupDB()
    end

    local options = {
        type = "group",
        name = "Nameplates",
        childGroups = "tab",
        order = 20,
        args = {
            isEnabled = {
                type = "toggle",
                name = "Enable Module",
                get = function()
                    return DRT.db.profile.modules["NP"].enabled
                end,
                set = function(_, value)
                    DRT.db.profile.modules["NP"].enabled = value
                    if value then
                        DRT:EnableModule("NP")
                    else
                        DRT:DisableModule("NP")
                    end
                end,
                order = 100
            },
            resetButton = {
                type = "execute",
				name = "Reset Module",
                desc = "Restore default settings for the entire module.",
				func = function ()
                    self:ResetModule()
                end,
                disabled = function ()
                    return not self:IsEnabled()
                end,
                order = 200
            },
            separator1 = {
                type = "description",
                name = "",
                width = "full",
                order = 300
            },
        }
    }

    return options
end
