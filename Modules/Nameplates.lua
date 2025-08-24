local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local ACR = LibStub("AceConfigRegistry-3.0")
local NP = DRT:NewModule("NP", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")


function NP:OnInitialize()

end


function NP:OnEnable()
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    self.unitContainers = self.unitContainers or {}
    self.frames = self.frames or {}
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

    if not self.unitContainers[unitGUID] then
        self:CreateFrames(nameplateFrame, unitGUID)
    end
end


function NP:NAME_PLATE_UNIT_REMOVED(_, nameplateUnit)
    local unitGUID = UnitGUID(nameplateUnit)
    local nameplateFrame = C_NamePlate.GetNamePlateForUnit(nameplateUnit)

    if not nameplateFrame then return end

    if unitGUID then
        self.unitContainers[unitGUID] = nil
    end
end


function NP:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()

    if eventType == "SPELL_AURA_APPLIED" then
        -- Use DRList:ContainsCC(spellId) to check if this is a relevant DR spell
        -- Then attach cooldown to nameplate associated with destGUID
    end
end


function NP:CreateFrames(nameplateFrame, unitGUID)
    print("CreateFrame" .. nameplateFrame:GetName())
    -- Create the container frame for this unit if it doesn't exist
    local container = CreateFrame("Frame", "NPContainer." .. unitGUID, nameplateFrame)
    self.unitContainers[unitGUID] = container

    -- Create the container texture
    container.texture = container:CreateTexture(nil, "OVERLAY")
    container.texture:SetAllPoints()

    -- Create the container text label
    container.text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.text:SetPoint("CENTER", container, "CENTER", 0, 0)
    container.text:SetDrawLayer("OVERLAY", 2)

    -- Create the category frame
    local frame = CreateFrame("Frame", nil, container)
    frame:SetSize(24, 24)
    frame:SetPoint("TOPRIGHT", nameplateFrame, "TOPRIGHT", -5, -5) -- Adjust position as needed

    -- Create the icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") -- Default texture

    -- Create the cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:SetDrawEdge(true)
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.75)

    -- Store reference
    self.frames = self.frames or {}
    self.frames[nameplateFrame] = frame
end



function NP:StyleFrames()

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
