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
    self.trackedUnits = self.trackedUnits or {}
end


function NP:OnDisable()

end


function NP:OnProfileChanged()

end


function NP:SetupDB()
    self.db = DRT.db:RegisterNamespace("NP", {
        profile = {
            drCategories = {
                ["*"] = {
                    priority = 0,
                    order = 0,
                    icon = "dynamic",
                    enabled = false,
                },
                stun = {
                    priority = 7,
                    order = 1,
                    icon = "dynamic",
                    enabled = true,
                },
                disorient = {
                    priority = 6,
                    order = 2,
                    icon = "dynamic",
                    enabled = true,
                },
                incapacitate = {
                    priority = 5,
                    order = 3,
                    icon = "dynamic",
                    enabled = true,
                },
                silence = {
                    priority = 4,
                    order = 4,
                    icon = "dynamic",
                    enabled = false,
                },
                disarm = {
                    priority = 3,
                    order = 5,
                    icon = "dynamic",
                    enabled = false,
                },
                knockback = {
                    priority = 2,
                    order = 6,
                    icon = "dynamic",
                    enabled = false,
                },
                root = {
                    priority = 1,
                    order = 7,
                    icon = "dynamic",
                    enabled = false,
                },
            },

            -- Icon settings
            cropIcons = true,
            frameSize = 30,

            -- Cooldown settings
            cooldown = true,
            cooldownReverse = true,
            cooldownSwipeAlpha = 0.6,
            cooldownEdge = true,
            cooldownNumbersHide = false,
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
    if NP.testing then return end


    local function GetDebuffDuration(unitToken, spellID)
        if not UnitExists(unitToken) then return nil end

        for index = 1, 255 do
            local aura = C_UnitAuras.GetDebuffDataByIndex(unitToken, index, "HARMFUL")
            if not aura then
                break
            end

            if aura.spellId == spellID then
                local timeLeft = aura.expirationTime and (aura.expirationTime - GetTime()) or 0
                return aura.duration, aura.expirationTime, timeLeft
            end
        end

        return nil
    end


    local _, eventType, _, _, _, _, _, destGUID, _, destFlags, _, spellID, _, _, auraType = CombatLogGetCurrentEventInfo()

    -- Check all debuffs found in the combat log
    if auraType == "DEBUFF" then
        -- Get the DR category or exit immediately if current debuff doesn't have a DR
        local drCategory, sharedCategories = DRList:GetCategoryBySpellID(spellID)
        if not drCategory then return end

        -- Check if unit that got the debuff is a player
        local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
        if not isPlayer and not DRList:IsPvECategory(drCategory) then return end

        self.trackedUnits[destGUID] = self.trackedUnits[destGUID] or {}
        self.trackedUnits[destGUID][drCategory] = self.trackedUnits[destGUID][drCategory] or {}

        local data = self.trackedUnits[destGUID][drCategory]
        local currentTime = GetTime()

        if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
            -- Set how many times the DR category has been applied so far
            if data.diminished == nil or currentTime >= (data.expirationTime or 0) then -- is nil or DR expired
                local duration = 1
                data.diminished = DRList:NextDR(duration, drCategory)
            else
                data.diminished = DRList:NextDR(data.diminished, drCategory)
            end

            local debuffDuration
            for i= 1, 40 do
                local unitToken = "nameplate" .. i
                debuffDuration, _, _ = GetDebuffDuration(unitToken, spellID)
                if debuffDuration then print(debuffDuration) break end
            end

            data.startTime = currentTime
            if isPlayer then
                data.resetTime = DRList:GetResetTime(drCategory) + (debuffDuration or 0)
            else
                data.resetTime = DRList:GetResetTime("npc") + (debuffDuration or 0)
            end
            data.expirationTime = data.startTime + data.resetTime
            -- Trigger main DR category
            self:StartOrUpdateDRTimer(drCategory, destGUID, spellID)

            -- Trigger any shared DR categories
            if sharedCategories then
                for i = 1, #sharedCategories do
                    if sharedCategories[i] ~= drCategory then
                        self:StartOrUpdateDRTimer(sharedCategories[i], destGUID, spellID)
                    end
                end
            end
        end

        -- The debuff has faded or refreshed, DR timer starts
        if eventType == "SPELL_AURA_REMOVED" then
            data.startTime = currentTime
            if isPlayer then
                data.resetTime = DRList:GetResetTime(drCategory)
            else
                data.resetTime = DRList:GetResetTime("npc")
            end
            data.expirationTime = data.startTime + data.resetTime

            -- Trigger main DR category
            self:StartOrUpdateDRTimer(drCategory, destGUID, spellID)

            -- Trigger any shared DR categories
            if sharedCategories then
                for i = 1, #sharedCategories do
                    if sharedCategories[i] ~= drCategory then
                        self:StartOrUpdateDRTimer(sharedCategories[i], destGUID, spellID)
                    end
                end
            end
        end
    end

    if eventType == "UNIT_DIED" then
        if self.trackedUnits and self.trackedUnits[destGUID] then
            self.trackedUnits[destGUID] = nil
        end
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
        frame:SetPoint("BOTTOMRIGHT", nameplateFrame, "BOTTOMRIGHT", 0, 0)
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
    local settings = self.db.profile

    for nameplateUnit, _ in pairs(self.unitContainers) do
        local container = self.unitContainers[nameplateUnit]

        for drCategory, _ in pairs(drCategories) do
            local frame = self.categoryFrames[nameplateUnit][drCategory]

            frame:SetSize(settings.frameSize, settings.frameSize)
            if settings.cropIcons then
                frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                frame.icon:SetTexCoord(0, 1, 0, 1)
            end

            frame.cooldown:SetDrawBling(false)
            frame.cooldown:SetDrawSwipe(settings.cooldown)
            frame.cooldown:SetReverse(settings.cooldownReverse)
            frame.cooldown:SetSwipeColor(0, 0, 0, settings.cooldownSwipeAlpha)
            frame.cooldown:SetDrawEdge(settings.cooldown and settings.cooldownEdge)
            frame.cooldown:SetHideCountdownNumbers(settings.cooldownNumbersHide)
        end
    end
end


function NP:UpdateFrames()
    print("UpdateFrames")
end


function NP:StartOrUpdateDRTimer(drCategory, unitGUID, spellID)
--[[     self.trackedUnits[unitGUID] = self.trackedUnits[unitGUID] or {}
    self.trackedUnits[unitGUID][drCategory] = self.trackedUnits[unitGUID][drCategory] or {} ]]

    local data = self.trackedUnits[unitGUID][drCategory]

    if spellID then
        data.lastSpellID = spellID
    end

    local nameplateUnit
    for unit, unitData in pairs(self.unitContainers) do
        if unitData.unitGUID == unitGUID then
            nameplateUnit = unit
        end
    end

    local frame = self.categoryFrames[nameplateUnit] and self.categoryFrames[nameplateUnit][drCategory]
    local categoryIcon = self.db.profile.drCategories[drCategory].icon

    if frame then
        local iconTexture
        if categoryIcon == "dynamic" then
            local spellInfo = C_Spell.GetSpellInfo(data.lastSpellID)
            iconTexture = spellInfo.originalIconID
        else
            local spellInfo = C_Spell.GetSpellInfo(categoryIcon)
            iconTexture = spellInfo.originalIconID
        end

        frame:SetAlpha(1)
        frame.active = true

        frame.icon:SetTexture(iconTexture)

        frame.cooldown:SetCooldown(data.startTime, data.resetTime)

        local diminishedText = {
            [0.5] = "1",
            [0.25] = "2",
            [0] = "3",
        }
        local diminishedColor = {
            [0.5] = {0, 1, 0, 1},
            [0.25] = {1, 1, 0, 1},
            [0] = {1, 0, 0, 1},
        }

        local text = diminishedText[data.diminished] or ""
        local color = diminishedColor[data.diminished] or {1,1,1,1}

--[[         frame.drIndicator.text:SetText(text)
        frame.drIndicator.text:SetTextColor(unpack(color))

        for _, tex in pairs(frame.borderTextures) do
            tex:SetColorTexture(unpack(color))
        end

        for _, tex in pairs(frame.drIndicator.borderTextures) do
            tex:SetColorTexture(unpack(color))
        end ]]

        frame:SetScript("OnUpdate", function(f, elapsed)
            local currentTime = GetTime()
            if currentTime >= data.expirationTime then
                f:SetScript("OnUpdate", nil)
                f:SetAlpha(0)
                f.active = false
                NP:UpdateFrames()
            end
        end)
    end

    self:UpdateFrames()
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
