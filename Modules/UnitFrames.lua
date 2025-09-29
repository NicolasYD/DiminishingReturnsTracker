local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local ACR = LibStub("AceConfigRegistry-3.0")
local UF = DRT:NewModule("UF", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")
local drCategories = DRList:GetCategories()
drCategories["taunt"] = nil

function UF:OnInitialize()

end


function UF:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    self.unitContainers = self.unitContainers or {}
    self.categoryFrames = self.categoryFrames or {}
    self.trackedUnits = self.trackedUnits or {}

    -- Create category frames for all unit tokens
    for unitToken in pairs(self.db.profile.units) do
        self.categoryFrames[unitToken] = self.categoryFrames[unitToken] or {}
        if not self.unitContainers[unitToken] then
            self:CreateFrames(unitToken)
        end
    end

    self:ShowContainers()

    if DRT.testing then
        self:StartTest()
    end
end


function UF:OnDisable()
    self:HideContainers()

    if DRT.testing then
        self:StopTest()
    end
end


function UF:OnProfileChanged()
    self:StyleFrames()
    self:UpdateFrames()
end


function UF:SetupDB()
    local defaultCategories = {
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
    }

    local sharedOptions = {
        -- General settings
        enabled = true,
        categories = defaultCategories,
        customIndicator = false,

        -- Icon settings
        coloredBorder = true,
        drIndicator = true,
        cropIcons = true,
        growIcons = "LEFT",
        iconsSpacing = 5,
        borderSize = 1,
        frameSize = 30,
        frameLevel = 100,
        positionLocked = false,
        anchorToFrame = false,
        anchorTo = "UIParent",
        point = "CENTER",
        relativePoint = "CENTER",
        offsetX = 0,
        offsetY = 0,

        -- Cooldown settings
        cooldown = true,
        cooldownReverse = true,
        cooldownEdge = true,
        cooldownNumbersShow = true,
        cooldownSwipeAlpha = 0.6,
    }


    -- A helper function to shallow-copy and override table keys
    local function mergeTables(base, overrides)
        local result = {}
        for k, v in pairs(base) do
            result[k] = v
        end
        for k, v in pairs(overrides) do
            result[k] = v
        end
        return result
    end


    self.db = DRT.db:RegisterNamespace("UF", {
        profile = {
            units = {
                player = mergeTables(sharedOptions, {
                    offsetX = -100,
                    offsetY = -100,
                    order = 1,
                    }),
                target = mergeTables(sharedOptions, {
                    offsetX = 100,
                    offsetY = -100,
                    growIcons = "RIGHT",
                    order = 2,
                }),
                focus = mergeTables(sharedOptions, {
                    offsetX = 250,
                    offsetY = -100,
                    growIcons = "RIGHT",
                    order = 3,
                }),
                party1 = mergeTables(sharedOptions, {
                    offsetX = -300,
                    offsetY = 150,
                    growIcons = "RIGHT",
                    order = 4,
                }),
                party2 = mergeTables(sharedOptions, {
                    offsetX = -300,
                    offsetY = 100,
                    growIcons = "RIGHT",
                    order = 5,
                }),
                party3 = mergeTables(sharedOptions, {
                    enabled = false,
                    positionLocked = true,
                    offsetX = -300,
                    offsetY = 50,
                    growIcons = "RIGHT",
                    order = 6,
                }),
                party4 = mergeTables(sharedOptions, {
                    enabled = false,
                    positionLocked = true,
                    offsetX = -300,
                    growIcons = "RIGHT",
                    order = 7,
                }),
                arena1 = mergeTables(sharedOptions, {
                    offsetX = 300,
                    offsetY = 200,
                    order = 8,
                }),
                arena2 = mergeTables(sharedOptions, {
                    offsetX = 300,
                    offsetY = 150,
                    order = 9,
                }),
                arena3 = mergeTables(sharedOptions, {
                    offsetX = 300,
                    offsetY = 100,
                    order = 10,
                }),
            },
        },
    })
end


function UF:CreateFrames(unitToken)
    local function CreateBorderTextures(parent)
        local border = {}

        border.left = parent:CreateTexture(nil, "OVERLAY")
        border.right = parent:CreateTexture(nil, "OVERLAY")
        border.top = parent:CreateTexture(nil, "OVERLAY")
        border.bottom = parent:CreateTexture(nil, "OVERLAY")

        return border
    end

    -- Create the container frame and store the reference
    local container = CreateFrame("Button", "UFContainer." .. unitToken, UIParent)
    self.unitContainers[unitToken] = container

    -- Create the container texture
    container.texture = container:CreateTexture(nil, "OVERLAY")

    -- Create the container text label
    container.text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    for drCategory, _ in pairs(drCategories) do

        -- Create the DR category frame and store the reference
        local frame = CreateFrame("Frame", "UFFrame." .. unitToken .. "." .. drCategory, container)
        self.categoryFrames[unitToken] = self.categoryFrames[unitToken] or {}
        self.categoryFrames[unitToken][drCategory] = frame

        -- Create the icon texture
        frame.icon = frame:CreateTexture(nil, "BACKGROUND")

        -- Create the cooldown frame
        frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")

        -- Create the border frame and textures
        frame.border = CreateFrame("Frame", nil, frame)
        frame.borderTextures = CreateBorderTextures(frame.border)

        -- Create the DR indicator frame
        frame.drIndicator = CreateFrame("Frame", nil, frame)

        -- Create the DR indicator texture
        frame.drIndicator.texture = frame.drIndicator:CreateTexture(nil, "OVERLAY")

        -- Create the DR indicator text label
        frame.drIndicator.text = frame.drIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        -- Create the DR indicator border
        frame.drIndicator.border = CreateFrame("Frame", nil, frame.drIndicator)
        frame.drIndicator.borderTextures = CreateBorderTextures(frame.drIndicator.border)
    end

    self:StyleFrames()
end


function UF:StyleFrames()
    for unitToken, container in pairs(self.unitContainers) do
        local settings = self.db.profile.units[unitToken]

        local enabledFrameCount = 0
        for _, drSettings in pairs(settings.categories) do
            if drSettings.enabled then
                enabledFrameCount = enabledFrameCount + 1
            end
        end

        -- Container styling
        container:ClearAllPoints()
        container:SetPoint(settings.point, settings.anchorTo, settings.relativePoint, settings.offsetX, settings.offsetY)
        if settings.growIcons == "LEFT" or settings.growIcons == "RIGHT" then
            container:SetHeight(settings.frameSize)
            container:SetWidth(enabledFrameCount * settings.frameSize + math.max(0, enabledFrameCount - 1) * settings.iconsSpacing)
        elseif settings.growIcons == "UP" or settings.growIcons == "DOWN" then
            container:SetHeight(enabledFrameCount * settings.frameSize + math.max(0, enabledFrameCount - 1) * settings.iconsSpacing)
            container:SetWidth(settings.frameSize)
        end

        -- Container texture styling
        container.texture:ClearAllPoints()
        container.texture:SetAllPoints()
        if settings.positionLocked or not settings.enabled then
            container.texture:SetColorTexture(0, 0, 0, 0)
        else
            container.texture:SetDrawLayer("OVERLAY", 1)
            container.texture:SetColorTexture(0, 0, 0, 0.4)
        end


        -- Container text label styling
        container.text:ClearAllPoints()
        container.text:SetAllPoints()
        if settings.positionLocked or not settings.enabled then
            container.text:SetText("")
        else
            container.text:SetDrawLayer("OVERLAY", 2)
            if settings.growIcons == "LEFT" or settings.growIcons == "RIGHT" then
                container.text:SetText("DRT " .. unitToken)
            elseif settings.growIcons == "UP" or settings.growIcons == "DOWN" then
                container.text:SetText("DRT\n\n" .. unitToken)
            end
        end

        for drCategory, _ in pairs(drCategories) do
            local frame = self.categoryFrames[unitToken][drCategory]

            -- DR category frame styling
            frame:SetSize(settings.frameSize, settings.frameSize)
            frame:SetFrameLevel(settings.frameLevel)

            -- Icon texture styling
            frame.icon:ClearAllPoints()
            frame.icon:SetAllPoints()
            if settings.cropIcons then
                frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                frame.icon:SetTexCoord(0, 1, 0, 1)
            end

            -- Cooldown frame styling
            frame.cooldown:ClearAllPoints()
            frame.cooldown:SetAllPoints()
            frame.cooldown:SetDrawBling(false)
            frame.cooldown:SetDrawSwipe(settings.cooldown)
            frame.cooldown:SetReverse(settings.cooldownReverse)
            frame.cooldown:SetSwipeColor(0, 0, 0, settings.cooldownSwipeAlpha)
            frame.cooldown:SetDrawEdge(settings.cooldown and settings.cooldownEdge)
            frame.cooldown:SetHideCountdownNumbers(not settings.cooldownNumbersShow)

            -- Border frame styling
            frame.border:ClearAllPoints()
            frame.border:SetAllPoints()
            frame.border:SetFrameLevel(frame.cooldown:GetFrameLevel() + 1)
            if settings.coloredBorder then
                frame.border:SetAlpha(1)
            else
                frame.border:SetAlpha(0)
            end

            for position, texture in pairs(frame.borderTextures) do
                local size = settings.borderSize

                if position == "left" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPLEFT", -size, size)
                    texture:SetPoint("BOTTOMLEFT", -size, -size)
                    texture:SetWidth(size)

                elseif position == "right" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPRIGHT", size, size)
                    texture:SetPoint("BOTTOMRIGHT", size, -size)
                    texture:SetWidth(size)

                elseif position == "top" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPLEFT", -size, size)
                    texture:SetPoint("TOPRIGHT", size, size)
                    texture:SetHeight(size)

                elseif position == "bottom" then
                    texture:ClearAllPoints()
                    texture:SetPoint("BOTTOMLEFT", -size, -size)
                    texture:SetPoint("BOTTOMRIGHT", size, -size)
                    texture:SetHeight(size)
                end
            end

            -- DR indicator frame styling
            frame.drIndicator:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.drIndicator:SetSize(0.3 * settings.frameSize, 0.3 * settings.frameSize)
            if settings.drIndicator then
                frame.drIndicator:SetAlpha(1)
            else
                frame.drIndicator:SetAlpha(0)
            end

            -- DR indicator texture styling
            frame.drIndicator.texture:SetAllPoints()
            frame.drIndicator.texture:SetDrawLayer("OVERLAY", 1)
            frame.drIndicator.texture:SetColorTexture(0, 0, 0, 1)

            -- DR indicator text label styling
            local fontSize = 0.3 * settings.frameSize
            local fontPath, _, fontFlags = frame.drIndicator.text:GetFont()

            frame.drIndicator.text:SetPoint("CENTER", frame.drIndicator, "CENTER", 0, 0)
            frame.drIndicator.text:SetDrawLayer("OVERLAY", 2)
            frame.drIndicator.text:SetFont(fontPath, fontSize, fontFlags)

            -- DR indicator border frame styling
            frame.drIndicator.border:ClearAllPoints()
            frame.drIndicator.border:SetAllPoints()
            frame.drIndicator.border:SetFrameLevel(frame.drIndicator:GetFrameLevel() + 1)
            if settings.coloredBorder then
                frame.drIndicator.border:SetAlpha(1)
            else
                frame.drIndicator.border:SetAlpha(0)
            end

            for position, texture in pairs(frame.drIndicator.borderTextures) do
                local size = settings.borderSize

                if position == "left" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPLEFT", -size, size)
                    texture:SetPoint("BOTTOMLEFT", -size, -size)
                    texture:SetWidth(size)

                elseif position == "right" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPRIGHT", size, size)
                    texture:SetPoint("BOTTOMRIGHT", size, -size)
                    texture:SetWidth(size)

                elseif position == "top" then
                    texture:ClearAllPoints()
                    texture:SetPoint("TOPLEFT", -size, size)
                    texture:SetPoint("TOPRIGHT", size, size)
                    texture:SetHeight(size)

                elseif position == "bottom" then
                    texture:ClearAllPoints()
                    texture:SetPoint("BOTTOMLEFT", -size, -size)
                    texture:SetPoint("BOTTOMRIGHT", size, -size)
                    texture:SetHeight(size)
                end
            end
        end

        self:MoveFrame(container, unitToken, function (f)
            ACR:NotifyChange("DRT") -- Update values in options
        end)
    end
end


function UF:UpdateFrames()
    if not self.categoryFrames then
        return
    end

    local growDirection = {
        LEFT = {relativePoint = "RIGHT", point = "LEFT"},
        RIGHT = {relativePoint = "LEFT", point = "RIGHT"},
        UP = {relativePoint = "BOTTOM", point = "TOP"},
        DOWN = {relativePoint = "TOP", point = "BOTTOM"},
    }

    for unitToken, categories in pairs(self.categoryFrames) do
        local settings = self.db.profile.units[unitToken]
        local container = self.unitContainers[unitToken]
        local activeFrames = {}
        local enabledFrameCount = 0

        for drCategory, frame in pairs(categories) do
            frame.enabled = self.db.profile.units[unitToken].categories[drCategory].enabled

            if frame.enabled then
                enabledFrameCount = enabledFrameCount + 1
            end

            if frame.active and frame.enabled then
                table.insert(activeFrames, {
                    category = drCategory,
                    frame = frame,
                    priority = self.db.profile.units[unitToken].categories[drCategory].priority,
                })
            else
                frame:SetAlpha(0)
            end
        end

        table.sort(activeFrames, function(a, b)
            return a.priority > b.priority
        end)

        local lastFrame
        for _, entry in ipairs(activeFrames) do
            local frame = entry.frame
            local direction = settings.growIcons
            local relativePoint = growDirection[direction].relativePoint
            local point = growDirection[direction].point
            local spacing = settings.iconsSpacing
            frame:ClearAllPoints()
            if not lastFrame then
                frame:SetPoint(relativePoint, container)
            else
                frame:SetPoint(
                    relativePoint,
                    lastFrame,
                    point,
                    (point == "RIGHT" and spacing) or (point == "LEFT" and -spacing) or 0,
                    (point == "TOP" and spacing) or (point == "BOTTOM" and -spacing) or 0
                )
            end
            lastFrame = frame
        end
    end
end


function UF:COMBAT_LOG_EVENT_UNFILTERED()
    if DRT.testing then return end


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

            local unitTokens = self:GetUnitTokens(destGUID)
            local debuffDuration
            for _, unitToken in ipairs(unitTokens) do
                debuffDuration, _, _ = GetDebuffDuration(unitToken, spellID)
                if debuffDuration then break end
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


function UF:GetUnitTokens(unitGUID)
    local unitTokens = {
        "player", "target", "focus",
        "party1", "party2", "party3", "party4",
        "arena1", "arena2", "arena3",
    }

    local matches = {}

    for _, unitToken in ipairs(unitTokens) do
        if UnitGUID(unitToken) == unitGUID then
            table.insert(matches, unitToken)
        end
    end
    return matches
end


function UF:PLAYER_TARGET_CHANGED()
    if DRT.testing then return end

    local targetGUID = UnitGUID("target")
    local trackedUnit = self.trackedUnits and self.trackedUnits[targetGUID]
    local unitToken = "target"
    local targetFrames = self.categoryFrames[unitToken]

    -- Hide all frames associated with "target" when the player changes target
    for _, targetFrame in pairs(targetFrames) do
        if targetFrame then
            targetFrame:SetAlpha(0)
        end
    end

    if not trackedUnit then return end

    for drCategory, data in pairs(trackedUnit) do
        local frame = self.categoryFrames[unitToken][drCategory]

        if frame then
            if data.expirationTime and GetTime() < data.expirationTime then
                self:StartOrUpdateDRTimer(drCategory, targetGUID)
            end
        end
    end
end


function UF:GROUP_ROSTER_UPDATE()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "arena" then
        self:HideAllIcons()
        self:ResetDRData()
        self:SetPartyAnchorTo()
    end
end


function UF:HideAllIcons()
    if self.categoryFrames then
        for unit, _ in pairs(self.categoryFrames) do
            for category, _ in pairs(self.categoryFrames[unit]) do
                self.categoryFrames[unit][category]:SetAlpha(0)
            end
        end
    end
end


function UF:ResetDRData()
    if self.trackedUnits then
        for unitGUID, _ in pairs(self.trackedUnits) do
            for drCategory, _ in pairs(self.trackedUnits[unitGUID]) do
                self.trackedUnits[unitGUID][drCategory] = nil
            end
        end
    end
end


function UF:SetPartyAnchorTo()
    local partyMember = {
        "party1",
        "party2",
        "party3",
        "party4",
    }
    local partyFrames = {
        _G["CompactPartyFrameMember1"],
        _G["CompactPartyFrameMember2"],
        _G["CompactPartyFrameMember3"],
        _G["CompactPartyFrameMember4"],
        _G["CompactPartyFrameMember5"],
    }

    for _, member in ipairs(partyMember) do
        local settings = self.db.profile.units[member].anchorTo
        if settings:match("CompactPartyFrameMember") then
            for _, frame in ipairs(partyFrames) do
                if UnitGUID(member) == UnitGUID(frame.unit) then
                    local frameName = frame:GetName()
                    self.db.profile.units[member].anchorTo = frameName
                end
            end
        end
    end
end


function UF:HideContainers(unitToken)
    if not self.unitContainers then return end

    if unitToken then
        local frame = self.unitContainers[unitToken]
        if frame and frame.Hide then
            frame:Hide()
        end
    else
        for _, frame in pairs(self.unitContainers) do
            if frame and frame.Hide then
                frame:Hide()
            end
        end
    end
end


function UF:ShowContainers(unitToken)
    if not self.unitContainers then return end

    if unitToken then
        local frame = self.unitContainers[unitToken]
        if frame and frame.Hide then
            frame:Show()
        end
    else
        for _, frame in pairs(self.unitContainers) do
            if frame and frame.Show then
                frame:Show()
            end
        end
    end
end


function UF:StartOrUpdateDRTimer(drCategory, unitGUID, spellID)
    local tracked = self.trackedUnits[unitGUID]

    if not tracked then return end

    local data = self.trackedUnits[unitGUID][drCategory]

    if spellID then
        data.lastSpellID = spellID
    end

    local unitTokens
    if DRT.testing then
        unitTokens = {unitGUID}
    else
        unitTokens = self:GetUnitTokens(unitGUID)
    end

    for _, unitToken in ipairs(unitTokens) do
        if self.db.profile.units[unitToken] and self.db.profile.units[unitToken].enabled then
            local frame = self.categoryFrames[unitToken] and self.categoryFrames[unitToken][drCategory]
            local categoryIcon = self.db.profile.units[unitToken].categories[drCategory].icon

            if data and frame then
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

                local text = diminishedText[data.diminished] or "X"
                local color = diminishedColor[data.diminished] or {1, 1, 1, 1}

                for _, texture in pairs(frame.borderTextures) do
                    texture:SetColorTexture(unpack(color))
                end

                frame.drIndicator.text:SetText(text)
                frame.drIndicator.text:SetTextColor(unpack(color))

                for _, texture in pairs(frame.drIndicator.borderTextures) do
                    texture:SetColorTexture(unpack(color))
                end

                frame:SetScript("OnUpdate", function(f, elapsed)
                    local currentTime = GetTime()
                    if currentTime >= data.expirationTime then
                        f:SetScript("OnUpdate", nil)
                        f:SetAlpha(0)
                        f.active = false
                        UF:UpdateFrames()
                    end
                end)
            end
        end
    end

    self:UpdateFrames()
end


function UF:StartTest()
    local count = 0


    local function GetRandomSpell(tbl, val)
        local keys = {}
        for k in pairs(tbl) do
            table.insert(keys, k)
        end

        local tried = {}
        while #tried < #keys do
            local i
            repeat
                i = math.random(#keys)
            until not tried[i]

            tried[i] = true
            local key = keys[i]
            if tbl[key] == val then
                return key
            end
        end
    end


    local function TestIcons()
        local unitsTokens = self.db.profile.units
        local spellList = DRList:GetSpells()
        local reset = DRList:GetResetTime("stun")

        for drCategory in pairs(drCategories) do
            local spellID = GetRandomSpell(spellList, drCategory)
            for unitToken in pairs(unitsTokens) do
                UF.trackedUnits[unitToken] = UF.trackedUnits[unitToken] or {}
                UF.trackedUnits[unitToken][drCategory] = UF.trackedUnits[unitToken][drCategory] or {}

                local currentTime = GetTime()
                local data = UF.trackedUnits[unitToken][drCategory]
                data.startTime = currentTime
                data.resetTime = DRList:GetResetTime(drCategory)
                data.expirationTime = data.startTime + data.resetTime

                if data.diminished == nil or currentTime >= (data.expirationTime or 0) then -- is nil or DR expired
                    local duration = 1
                    data.diminished = DRList:NextDR(duration, drCategory)
                else
                    data.diminished = DRList:NextDR(data.diminished, drCategory)
                end

                self:StartOrUpdateDRTimer(drCategory, unitToken, spellID)
            end
        end

        UF.testTimer = C_Timer.NewTimer(reset, function()
            count = count + 1
            if count == 3 then
                UF.trackedUnits = {}
                count = 0
            end
            TestIcons()
        end)
    end

    TestIcons()
end


function UF:StopTest()
    self.trackedUnits = {}
    if self.categoryFrames then
        for unitToken in pairs(self.categoryFrames) do
            for drCategory in pairs(self.categoryFrames[unitToken]) do
                local frame = self.categoryFrames[unitToken][drCategory]
                frame.active = false
                frame:SetAlpha(0)
            end
        end
    end
    if self.testTimer then
        self.testTimer:Cancel()
        self.testTimer = nil
    end
end


function UF:ResetModule()
    self.db:ResetProfile()
    self:StyleFrames()
    self:UpdateFrames()
end


function UF:ResetUnitSettings(unit)
    -- Deep copy utility function
    local function DeepCopy(from)
        if type(from) ~= "table" then return from end
        local to = {}
        for k, v in pairs(from) do
            to[k] = DeepCopy(v)
        end
        return to
    end


    local defaults = self.db.defaults.profile.units[unit]
    if not defaults then
        return
    end

    -- Deep copy default settings to profile.units[unit]
    self.db.profile.units[unit] = DeepCopy(defaults)
    self:StyleFrames()
end


function UF:CopySettings(fromUnit, toUnit, excludeList)
    local fromSettings = self.db.profile.units[fromUnit]
    local toSettings = self.db.profile.units[toUnit]
    if not fromSettings or not toSettings then return end

    -- Convert exclude list to a lookup table
    local excludeMap = {}
    if excludeList then
        for _, key in ipairs(excludeList) do
            excludeMap[key] = true
        end
    end

    -- Deep copy with exclusions (shallow level only here)
    for k, v in pairs(fromSettings) do
        if not excludeMap[k] then
            if type(v) == "table" then
                toSettings[k] = CopyTable(v)  -- WoW's built-in deep copy
            else
                toSettings[k] = v
            end
        end
    end
end


function UF:MoveFrame(frame, unit, onStopCallback)
    local settings = self.db.profile.units[unit]
    local positionLocked = settings.positionLocked

    if positionLocked then
        -- Disable dragging and clicking
        frame:EnableMouse(false)
        frame:SetMovable(false)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetScript("OnClick", nil)
    else
        -- Enable dragging and clicking
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:RegisterForClicks("AnyUp")
        frame:SetClampedToScreen(true)

        -- Save the original anchor
        local origPoint, origRelativeTo, origRelativePoint, _, _ = frame:GetPoint()

        local dragStartX, dragStartY
        local isDragging = false  -- Track if the frame is being dragged

        frame:SetScript("OnDragStart", function(f)
            dragStartX, dragStartY = f:GetCenter()
            f:StartMoving()
            isDragging = true  -- Start dragging
        end)

        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            isDragging = false  -- Stop dragging

            local oldOffsetX = settings.offsetX
            local oldOffsetY = settings.offsetY

            local newX, newY = f:GetCenter()
            if newX and newY and dragStartX and dragStartY then
                local deltaX = newX - dragStartX
                local deltaY = newY - dragStartY

                local newOffsetX = (oldOffsetX or 0) + deltaX
                local newOffsetY = (oldOffsetY or 0) + deltaY

                -- Reapply the original anchor with updated offsets
                settings.offsetX = newOffsetX
                settings.offsetY = newOffsetY

                f:ClearAllPoints()
                f:SetPoint(origPoint, origRelativeTo, origRelativePoint, newOffsetX, newOffsetY)

                if type(onStopCallback) == "function" then
                    onStopCallback(f)
                end
            end
        end)

        -- Lock frame position on right click, but only if it's not being dragged
        frame:SetScript("OnClick", function(f, button)
            if button == "RightButton" and not isDragging then
                self.db.profile.units[unit].positionLocked = true
                self:StyleFrames()
            end
        end)

        -- Tooltip on mouse enter and leave
        frame:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_CURSOR")
            GameTooltip:SetText("Left Click:\nDrag to move frame\n\nRight Click:\nLock frame position")  -- Customize the tooltip text as needed
            GameTooltip:Show()
        end)

        frame:SetScript("OnLeave", function(f)
            GameTooltip:Hide()
        end)
    end
end


function UF:ReparentUnitContainer(unit, newParent)
    local frame = self.unitContainers[unit]

    local screenX = frame:GetLeft()
    local screenY = frame:GetBottom()

    -- Reparent
    frame:SetParent(newParent)

    -- Clear points to avoid conflicts
    frame:ClearAllPoints()

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale()

    -- Adjust for scale differences
    local adjustedX = screenX * frameScale / uiScale
    local adjustedY = screenY * frameScale / uiScale

    local point = "BOTTOMLEFT"
    local relativePoint = "BOTTOMLEFT"

    -- Set new point relative to UIParent to keep it in the same spot
    frame:SetPoint(point, UIParent, relativePoint, adjustedX, adjustedY)

    self.db.profile.units[unit].anchorTo = newParent:GetName()
    self.db.profile.units[unit].point = point
    self.db.profile.units[unit].relativePoint = relativePoint
    self.db.profile.units[unit].offsetX = adjustedX
    self.db.profile.units[unit].offsetY = adjustedY

end


function UF:BuildGeneralOptions(unit)
    local pointValues = {
        TOP = "TOP",
        TOPLEFT = "TOPLEFT",
        TOPRIGHT = "TOPRIGHT",
        LEFT = "LEFT",
        CENTER = "CENTER",
        RIGHT = "RIGHT",
        BOTTOM = "BOTTOM",
        BOTTOMLEFT = "BOTTOMLEFT",
        BOTTOMRIGHT = "BOTTOMRIGHT",
    }

    local generalOptions = {
        widget = {
            type = "group",
            name = "Widget",
            desc = "Widget settings",
            inline = true,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 2,
            args = {
                header1 = {
                type = "header",
                name = "Cooldown Options",
                width = "full",
                order = 10,
                },
                cooldown = {
                    type = "toggle",
                    name = "Cooldown Animation",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cooldown
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldown = value
                        self:StyleFrames()
                    end,
                    order = 20,
                },
                cooldownReverse = {
                    type = "toggle",
                    name = "Cooldown Reverse",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cooldownReverse
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldownReverse = value
                        self:StyleFrames()
                    end,
                    order = 30,
                },
                cooldownEdge = {
                    type = "toggle",
                    name = "Cooldown Edge",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cooldownEdge
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldownEdge = value
                        self:StyleFrames()
                    end,
                    order = 40,
                },
                cooldownNumbersShow = {
                    type = "toggle",
                    name = "Cooldown Numbers",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cooldownNumbersShow
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldownNumbersShow = value
                        self:StyleFrames()
                    end,
                    order = 41,
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 50,
                },
                cooldownSwipeAlpha = {
                    type = "range",
                    name = "Cooldown Swipe Alpha",
                    desc = "",
                    min = 0,
                    max = 1,
                    step = 0.1,
                    get = function()
                        return self.db.profile.units[unit].cooldownSwipeAlpha
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldownSwipeAlpha = value
                        self:StyleFrames()
                    end,
                    order = 60,
                },
                separator2 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 70,
                },
                header2 = {
                type = "header",
                name = "Icon Options",
                width = "full",
                order = 80,
                },
                coloredBorder = {
                    type = "toggle",
                    name = "Colored Border",
                    desc = "Show a colored border that indicates the DR level",
                    get = function()
                        return self.db.profile.units[unit].coloredBorder
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].coloredBorder = value
                        self:StyleFrames()
                    end,
                    order = 88,
                },
                drIndicator = {
                    type = "toggle",
                    name = "DR Indicator",
                    desc = "Show an indicator for the DR level",
                    get = function()
                        return self.db.profile.units[unit].drIndicator
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].drIndicator = value
                        self:StyleFrames()
                    end,
                    order = 89,
                },
                cropIcons = {
                    type = "toggle",
                    name = "Crop Icons",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cropIcons
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cropIcons = value
                        self:StyleFrames()
                    end,
                    order = 90,
                },
                separator3 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 100,
                },
                growIcons = {
                    type = "select",
                    name = "Grow Direction",
                    desc = "Choose in which direction new icons will be shown",
                    values = {
                        ["LEFT"] = "LEFT",
                        ["RIGHT"] = "RIGHT",
                        ["UP"] = "UP",
                        ["DOWN"] = "DOWN"
                    },
                    get = function()
                        return self.db.profile.units[unit].growIcons
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].growIcons = value
                        self:StyleFrames()
                        self:UpdateFrames()
                    end,
                    order = 110,
                },
                iconsSpacing = {
                    type = "range",
                    name = "Icon Spacing",
                    desc = "Adjust the gap between the icons",
                    min = 0,
                    max = 200,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].iconsSpacing
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].iconsSpacing = value
                        self:StyleFrames()
                        self:UpdateFrames()
                    end,
                    order = 120,
                },
                separator4 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 130,
                },
                borderSize = {
                    type = "range",
                    name = "Colored Border Size",
                    desc = "",
                    min = 1,
                    max = 20,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].borderSize
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].borderSize = value
                        self:StyleFrames()
                    end,
                    order = 140,
                },
                frameSize = {
                    type = "range",
                    name = "Icons Frame Size",
                    desc = "",
                    min = 0,
                    max = 200,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].frameSize
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].frameSize = value
                        self:StyleFrames()
                    end,
                    order = 150,
                },
            },
        },
        position = {
            type = "group",
            name = "Position",
            desc = "Position settings",
            inline = true,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 3,
            args = {
                positionLocked = {
                    type = "toggle",
                    name = "Lock Position",
                    desc = "If unlocked, icons can be moved by mouse.",
                    get = function()
                        return self.db.profile.units[unit].positionLocked
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].positionLocked = value
                        self:StyleFrames()
                    end,
                    order = 10,
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 20,
                },
                anchorToFrame = {
                    type = "toggle",
                    name = "Anchor To Frame",
                    desc = "Anchor the icons to a specific frame.",
                    get = function()
                        return self.db.profile.units[unit].anchorToFrame
                    end,
                    set = function(_, value)
                        if not value then
                            self:ReparentUnitContainer(unit, UIParent)
                            ACR:NotifyChange("DRT")
                        end
                        self.db.profile.units[unit].anchorToFrame = value
                        self:StyleFrames()
                    end,
                    order = 30,
                },
                separator2 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 40,
                },
                anchorTo = {
                    type = "input",
                    name = "Anchor Frame Name",
                    desc = "Enter the name of the frame to anchor this icon to.",
                    get = function()
                        return self.db.profile.units[unit].anchorTo or ""
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].anchorTo = value
                        self:StyleFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled or not self.db.profile.units[unit].anchorToFrame
                    end,
                    order = 50,
                },
                selectFrame = {
                    type = "execute",
                    name = "Select Frame",
                    desc = "Click on the frame that you want to select.",
                    func = function()
                        DRT:FrameSelector(function(selectedFrame)
                            self.db.profile.units[unit].anchorTo = selectedFrame
                            self.db.profile.units[unit].point = "CENTER"
                            self.db.profile.units[unit].relativePoint = "CENTER"
                            self.db.profile.units[unit].offsetX = 0
                            self.db.profile.units[unit].offsetY = 0
                            ACR:NotifyChange("DRT")
                            self:StyleFrames()
                        end)
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled or not self.db.profile.units[unit].anchorToFrame
                    end,
                    order = 60,
                },
                separator3 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 70,
                },
                point = {
                    type = "select",
                    name = "Anchor Frame Point",
                    desc = "Which point of the anchor frame to anchor to.",
                    values = pointValues,
                    get = function()
                        return self.db.profile.units[unit].point
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].point = value
                        self:StyleFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled
                    end,
                    order = 80,
                },
                relativePoint = {
                    type = "select",
                    name = "Icon Frame Point",
                    desc = "Which point of the icon frame to anchor to.",
                    values = pointValues,
                    get = function()
                        return self.db.profile.units[unit].relativePoint
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].relativePoint = value
                        self:StyleFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled
                    end,
                    order = 90,
                },
                separator4 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 100,
                },
                offsetX = {
                    type = "range",
                    name = "Icon Frame Offset X",
                    desc = "",
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].offsetX
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].offsetX = value
                        self:StyleFrames()
                    end,
                    order = 110,
                },
                offsetY = {
                    type = "range",
                    name = "Icon Frame Offset Y",
                    desc = "",
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].offsetY
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].offsetY = value
                        self:StyleFrames()
                    end,
                    order = 120,
                },
            }
        }

    }

    return generalOptions
end


function UF:BuildDiminishingReturnsOptions(unit)
    local diminishingReturnsOptions = {
        separator1 = {
            type = "description",
            name = "",
            width = "full",
            order = 98,
        },
         header1 = {
            type = "header",
            name = "Tracked DR Categories",
            order = 99,
        },
         separator2 = {
            type = "description",
            name = "",
            width = "full",
            order = 198,
        },
        header2 = {
            type = "header",
            name = "DR Category Icons",
            order = 199,
        },
        separator3 = {
            type = "description",
            name = "",
            width = "full",
            order = 298,
        },
        header3 = {
            type = "header",
            name = "DR Category Priorities",
            order = 299,
        },
    }

    local count = 0
    for _ in pairs(drCategories) do
        count = count + 1
    end

    for category, categoryName in pairs(drCategories) do
        local spellList = DRList:GetSpells()

        local iconTable = {
            ["dynamic"] = "|TInterface\\ICONS\\INV_Misc_QuestionMark:16:16|t Dynamic",
        }
        local sortingTable = {
            "dynamic",
        }
        local seen = {}

        for spellID, drCategory in pairs(spellList) do
            local spellInfo = C_Spell.GetSpellInfo(spellID)

            if spellInfo and drCategory == category then
                local spellName = spellInfo.name
                local icon = spellInfo.originalIconID
                local value = "|T" .. icon .. ":16:16|t " .. spellName
                if not seen[value] then
                    iconTable[spellID] = value
                    table.insert(sortingTable, spellID)
                    seen[value] = "seen"
                end
            end
        end

        -- Sort spellIDs by spell name from iconTable value
        table.sort(sortingTable, function(a, b)
            if a == "dynamic" then return true end
            if b == "dynamic" then return false end

            local aText = iconTable[a]:match("|t%s*(.+)")
            local bText = iconTable[b]:match("|t%s*(.+)")
            return aText < bText
        end)

        diminishingReturnsOptions[category .. "Enabled"] = {
            type = "toggle",
            name = categoryName,
            desc = "Choose the DR categories that you want to track",
            get = function()
                return self.db.profile.units[unit].categories[category].enabled
            end,
            set = function(_, value)
                self.db.profile.units[unit].categories[category].enabled = value
                self:StyleFrames()
                if DRT.testing then
                    self:StopTest()
                    self:StartTest()
                end
            end,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 100 + self.db.profile.units[unit].categories[category].order,
        }

        diminishingReturnsOptions[category .. "Icon"] = {
            type = "select",
            name = categoryName,
            desc = "Choose the icon that you want to display for this DR category",
            values = iconTable,
            sorting = sortingTable,
            get = function()
                return self.db.profile.units[unit].categories[category].icon
            end,
            set = function(_, value)
                self.db.profile.units[unit].categories[category].icon = value
                self:StyleFrames()
                if DRT.testing then
                    self:StopTest()
                    self:StartTest()
                end
            end,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 200 + self.db.profile.units[unit].categories[category].order,
        }

        diminishingReturnsOptions[category .. "Priority"] = {
            type = "range",
            name = categoryName,
            desc = "",
            min = 0,
            max = count,
            step = 1,
            get = function ()
                return self.db.profile.units[unit].categories[category].priority
            end,
            set = function (_, value)
                self.db.profile.units[unit].categories[category].priority = value
                self:UpdateFrames()
            end,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 300 + self.db.profile.units[unit].categories[category].order,
        }
    end

    return diminishingReturnsOptions
end


function UF:GetOptions()
    if not self.db then
        self:SetupDB()
    end

    local options = {
        type = "group",
        name = "UnitFrames",
        childGroups = "tab",
        order = 10,
        args = {
            isEnabled = {
                type = "toggle",
                name = "Enable Module",
                get = function()
                    return DRT.db.profile.modules["UF"].enabled
                end,
                set = function(_, value)
                    DRT.db.profile.modules["UF"].enabled = value
                    if value then
                        DRT:EnableModule("UF")
                    else
                        DRT:DisableModule("UF")
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

    local count = 0
    for _ in pairs(drCategories) do
        count = count + 1
    end
    local copySettingsFrom = {}

    for unit in pairs(self.db.profile.units) do
        options.args[unit] = {
            type = "group",
            name = unit,
            order = self.db.profile.units[unit].order,
            childGroups = "tab",
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enable Unit",
                    desc = "Enable DR tracking for this unit",
                    get = function ()
                        return self.db.profile.units[unit].enabled
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].enabled = value
                        if value then
                            self:ShowContainers(unit)
                        else
                            self:HideContainers(unit)
                        end
                        self:StyleFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled()
                    end,
                    order = 100,
                },
                resetUnit = {
                    type = "execute",
                    name = "Reset Unit",
                    desc = "Restore default settings for this unit.",
                    func = function ()
                        self:ResetUnitSettings(unit)
                        self:UpdateFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled
                    end,
                    order = 109
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 110
                },
                copySettingsFrom = {
                    type = "select",
                    name = "Copy Settings From",
                    desc = "Copy settings from another unit.",
                    values = function(info)
                        local settings = self.db.profile.units
                        local currentUnit = info[#info - 1]
                        local values = {
                            ["_none"] = "None",
                        }

                        for unitToken in pairs(settings) do
                            if unitToken ~= currentUnit then
                                values[unitToken] = unitToken
                            end
                        end

                        return values
                    end,
                    sorting = function(info)
                        local settings = self.db.profile.units
                        local currentUnit = info[#info - 1]
                        local sorted = {"_none"}

                        for unitToken in pairs(settings) do
                            if unitToken ~= currentUnit then
                                table.insert(sorted, unitToken)
                            end
                        end

                        table.sort(sorted, function(a, b)
                            if a == "_none" then return true end
                            if b == "_none" then return false end
                            return (settings[a].order or 0) < (settings[b].order or 0)
                        end)

                        return sorted
                    end,
                    get = function(info)
                        return copySettingsFrom[unit] or "_none"
                    end,
                    set = function(info, value)
                        if value == "_none" then
                            copySettingsFrom[unit] = nil
                        else
                            copySettingsFrom[unit] = value
                        end
                    end,
                    disabled = function(info)
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled
                    end,
                    order = 120,
                },
                copySettings = {
                    type = "execute",
                    name = "Copy",
                    desc = "Copy settings from selected unit to this one.",
                    func = function(info)
                        local fromUnit = copySettingsFrom[unit]
                        local toUnit = info[#info - 1]
                        local exclude = {
                            "enabled",
                            "growIcons",
                            "positionLocked",
                            "anchorToFrame",
                            "anchorTo",
                            "point",
                            "relativePoint",
                            "offsetX",
                            "offsetY",
                            "order",
                        }
                        if fromUnit and toUnit and fromUnit ~= toUnit then
                            self:CopySettings(fromUnit, toUnit, exclude)
                        end
                        copySettingsFrom[unit] = nil
                        self:StyleFrames()
                        self:UpdateFrames()
                    end,
                    disabled = function ()
                        return not self:IsEnabled() or not self.db.profile.units[unit].enabled or not copySettingsFrom[unit]
                    end,
                    order = 130,
                },
                general = {
                    type = "group",
                    name = "General",
                    order = 200,
                    args = {}
                },
                diminishingReturns = {
                    type = "group",
                    name = "DRs",
                    order = 300,
                    args = {}
                },
            }
        }

        options.args[unit].args.general.args = self:BuildGeneralOptions(unit)
        options.args[unit].args.diminishingReturns.args = self:BuildDiminishingReturnsOptions(unit)
    end

    return options
end
