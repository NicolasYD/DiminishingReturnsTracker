local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local ACR = LibStub("AceConfigRegistry-3.0")
local Icons = DRT:NewModule("Icons", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")

function Icons:OnInitialize()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("START_TIMER")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    if not self.db then
        self:SetupDB()
    end
end


function Icons:OnEnable()
    local drCategories = DRList:GetCategories()
    drCategories["taunt"] = nil
    for unitToken in pairs(self.db.profile.units) do
        for drCategory in pairs(drCategories) do
            self:CreateFrame(unitToken, drCategory)
        end
    end
    self:UpdateFrame()
end


function Icons:OnDisable()
    self:HideAllIcons()
end


function Icons:SetupDB()
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
        enabled = true,
        cropIcons = true,
        frameSize = 30,
        anchorTo = "UIParent",
        anchorPoint = "TOPRIGHT",
        iconPoint = "TOPRIGHT",
        offsetX = 0,
        offsetY = 0,
        growIcons = "Left",
        iconsSpacing = 5,
        cooldown = true,
        cooldownReverse = true,
        cooldownSwipeAlpha = 0.6,
        cooldownEdge = true,
        cooldownNumbers = true,
        categories = defaultCategories,
        coloredBorder = true,
        drIndicator = true,
        borderSize = 1,
        customIndicator = false,
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


    self.db = DRT.db:RegisterNamespace("Icons", {
        profile = {
            units = {
                player = mergeTables(sharedOptions, {
                    anchorTo = "PlayerFrame",
                    offsetX = -20,
                    offsetY = -5,
                    growIcons = "Left",
                    order = 1,
                    }),
                target = mergeTables(sharedOptions, {
                    anchorTo = "TargetFrame",
                    anchorPoint = "TOPLEFT",
                    iconPoint = "TOPLEFT",
                    offsetX = 20,
                    offsetY = -5,
                    growIcons = "Right",
                    order = 2,
                }),
                focus = mergeTables(sharedOptions, {
                    enabled = false,
                    frameSize = 30,
                    anchorTo = "FocusFrame",
                    anchorPoint = "TOPLEFT",
                    iconPoint = "TOPLEFT",
                    offsetX = 20,
                    offsetY = -5,
                    growIcons = "Right",
                    order = 3,
                }),
                party1 = mergeTables(sharedOptions, {
                    enabled = false,
                    frameSize = 30,
                    anchorTo = "CompactPartyFrameMember2",
                    order = 4,
                }),
                party2 = mergeTables(sharedOptions, {
                    enabled = false,
                    frameSize = 30,
                    anchorTo = "CompactPartyFrameMember3",
                    order = 5,
                }),
                party3 = mergeTables(sharedOptions, {
                    enabled = false,
                    frameSize = 30,
                    anchorTo = "CompactPartyFrameMember4",
                    order = 6,
                }),
                party4 = mergeTables(sharedOptions, {
                    enabled = false,
                    frameSize = 30,
                    anchorTo = "CompactPartyFrameMember5",
                    order = 7,
                }),
            },
        },
    })
end


function Icons:CreateFrame(unit, category)
    local function CreateColoredBorder(parent, color, size)
        size = size or 1
        color = color or {1, 1, 1, 1}

        local borders = {}

        borders.top = parent:CreateTexture(nil, "OVERLAY")
        borders.top:SetColorTexture(unpack(color))
        borders.top:SetPoint("TOPLEFT", -size, size)
        borders.top:SetPoint("TOPRIGHT", size, size)
        borders.top:SetHeight(size)

        borders.bottom = parent:CreateTexture(nil, "OVERLAY")
        borders.bottom:SetColorTexture(unpack(color))
        borders.bottom:SetPoint("BOTTOMLEFT", -size, -size)
        borders.bottom:SetPoint("BOTTOMRIGHT", size, -size)
        borders.bottom:SetHeight(size)

        borders.left = parent:CreateTexture(nil, "OVERLAY")
        borders.left:SetColorTexture(unpack(color))
        borders.left:SetPoint("TOPLEFT", -size, size)
        borders.left:SetPoint("BOTTOMLEFT", -size, -size)
        borders.left:SetWidth(size)

        borders.right = parent:CreateTexture(nil, "OVERLAY")
        borders.right:SetColorTexture(unpack(color))
        borders.right:SetPoint("TOPRIGHT", size, size)
        borders.right:SetPoint("BOTTOMRIGHT", size, -size)
        borders.right:SetWidth(size)

        return borders
    end


    self.frames = self.frames or {}
    self.frames[unit] = self.frames[unit] or {}

    local frame = CreateFrame("Frame", "DRTFrame." .. unit .. "." .. category, UIParent)
    self.frames[unit][category] = frame

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()

    -- Cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    -- Border
    frame.border = CreateFrame("Frame", nil, frame)
    frame.border:SetAllPoints()
    frame.border:SetFrameLevel(frame.cooldown:GetFrameLevel() + 1)
    frame.borderTextures = CreateColoredBorder(frame.border)

    -- DR indicator frame
    frame.drIndicator = CreateFrame("Frame", nil, frame)
    frame.drIndicator:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.drIndicator:SetFrameLevel(frame.border:GetFrameLevel() + 1)

    -- DR indicator texture
    frame.drIndicator.texture = frame.drIndicator:CreateTexture(nil, "OVERLAY")
    frame.drIndicator.texture:SetAllPoints()
    frame.drIndicator.texture:SetDrawLayer("OVERLAY", 1)
    frame.drIndicator.texture:SetColorTexture(0, 0, 0, 1)

    -- DR indicator border
    frame.drIndicator.border = CreateFrame("Frame", nil, frame.drIndicator)
    frame.drIndicator.border:SetAllPoints()
    frame.drIndicator.border:SetFrameLevel(frame.drIndicator:GetFrameLevel() + 1)
    frame.drIndicator.borderTextures = CreateColoredBorder(frame.drIndicator.border)

    -- DR indicator text label
    frame.drIndicator.text = frame.drIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.drIndicator.text:SetPoint("CENTER", frame.drIndicator, "CENTER", 0, 0)
    frame.drIndicator.text:SetDrawLayer("OVERLAY", 2)
end


function Icons:COMBAT_LOG_EVENT_UNFILTERED()
    if Icons.testing then return end


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

        self.trackedPlayers = self.trackedPlayers or {}
        self.trackedPlayers[destGUID] = self.trackedPlayers[destGUID] or {}
        self.trackedPlayers[destGUID][drCategory] = self.trackedPlayers[destGUID][drCategory] or {}

        local data = self.trackedPlayers[destGUID][drCategory]
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
        if self.trackedPlayers and self.trackedPlayers[destGUID] then
            self.trackedPlayers[destGUID] = nil
        end
    end
end


function Icons:PLAYER_TARGET_CHANGED()
    if Icons.testing then return end

    local targetGUID = UnitGUID("target")
    local trackedUnit = self.trackedPlayers and self.trackedPlayers[targetGUID]
    local unitToken = "target"
    local targetFrames = self.frames[unitToken]

    -- Hide all frames associated with "target" when the player changes target
    for _, targetFrame in pairs(targetFrames) do
        if targetFrame then
            targetFrame:SetAlpha(0)
        end
    end

    if not trackedUnit then return end

    for drCategory, data in pairs(trackedUnit) do
        local frame = self.frames[unitToken][drCategory]

        if frame then
            if data.expirationTime and GetTime() < data.expirationTime then
                self:ShowDRIcons(drCategory, targetGUID)
            end
        end
    end
end


function Icons:START_TIMER(timerType, _)
    if timerType == 1 then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "arena" then
            self:SetPartyAnchorTo()
        end
    end
end


function Icons:GROUP_ROSTER_UPDATE()
    self:HideAllIcons()
    self:ResetDRData()
    self:SetPartyAnchorTo()
end


function Icons:HideAllIcons()
    if self.frames then
        for unit, _ in pairs(self.frames) do
            for category, _ in pairs(self.frames[unit]) do
                self.frames[unit][category]:SetAlpha(0)
            end
        end
    end
end


function Icons:ResetDRData()
    if self.trackedPlayers then
        for unitGUID, _ in pairs(self.trackedPlayers) do
            for drCategory, _ in pairs(self.trackedPlayers[unitGUID]) do
                self.trackedPlayers[unitGUID][drCategory] = nil
            end
        end
    end
end


function Icons:SetPartyAnchorTo()
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
        for _, frame in ipairs(partyFrames) do
            if UnitGUID(member) == UnitGUID(frame.unit) then
                local frameName = frame:GetName()
                self.db.profile.units[member].anchorTo = frameName
            end
        end
    end
end


function Icons:GetUnitTokens(unitGUID)
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


function Icons:StartOrUpdateDRTimer(drCategory, unitGUID, spellID)
    self.trackedPlayers = self.trackedPlayers or {}
    self.trackedPlayers[unitGUID] = self.trackedPlayers[unitGUID] or {}
    self.trackedPlayers[unitGUID][drCategory] = self.trackedPlayers[unitGUID][drCategory] or {}

    local data = self.trackedPlayers[unitGUID][drCategory]

    if spellID then
        data.lastSpellID = spellID
    end

    self:ShowDRIcons(drCategory, unitGUID)
end


function Icons:ShowDRIcons(drCategory, unitGUID)
    local unitTokens
    if Icons.testing then
        unitTokens = {unitGUID}
    else
        unitTokens = self:GetUnitTokens(unitGUID)
    end

    for _, unitToken in ipairs(unitTokens) do
        if self.db.profile.units[unitToken] then
            local frame = self.frames[unitToken][drCategory]
            local data = self.trackedPlayers[unitGUID][drCategory]
            local categoryIcon = self.db.profile.units[unitToken].categories[drCategory].icon

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

                frame.drIndicator.text:SetText(text)
                frame.drIndicator.text:SetTextColor(unpack(color))

                for _, tex in pairs(frame.borderTextures) do
                    tex:SetColorTexture(unpack(color))
                end

                for _, tex in pairs(frame.drIndicator.borderTextures) do
                    tex:SetColorTexture(unpack(color))
                end

                frame:SetScript("OnUpdate", function(self, elapsed)
                    local currentTime = GetTime()
                    if currentTime >= data.expirationTime then
                        self:SetScript("OnUpdate", nil)
                        self:SetAlpha(0)
                        self.active = false
                    end
                end)
            end
        end
    end

    self:UpdateFrame()
end


function Icons:UpdateFrame()
    if not self.frames then
        return
    end

    local growDirection = {
        Left = {iconPoint = "RIGHT", anchorPoint = "LEFT"},
        Right = {iconPoint = "LEFT", anchorPoint = "RIGHT"},
        Up = {iconPoint = "BOTTOM", anchorPoint = "TOP"},
        Down = {iconPoint = "TOP", anchorPoint = "BOTTOM"},
    }

    for unit in pairs(self.frames) do
        local activeFrames = {}

        for category, frame in pairs(self.frames[unit]) do
            frame.enabled = self.db.profile.units[unit].categories[category].enabled

            if frame.active and frame.enabled then
                table.insert(activeFrames, {
                    category = category,
                    frame = frame,
                    priority = self.db.profile.units[unit].categories[category].priority,
                })
            else
                frame:SetAlpha(0)
            end
        end

        table.sort(activeFrames, function(a, b)
            return a.priority > b.priority
        end)

        local lastFrame
        local settings = self.db.profile.units[unit]

        for _, entry in ipairs(activeFrames) do
            local frame = entry.frame
            frame:SetSize(settings.frameSize, settings.frameSize)
            frame:ClearAllPoints()

            if not lastFrame then
                frame:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)
            else
                local direction = settings.growIcons
                local iconPoint = growDirection[direction].iconPoint
                local anchorPoint = growDirection[direction].anchorPoint
                local spacing = settings.iconsSpacing

                frame:SetPoint(
                    iconPoint,
                    lastFrame,
                    anchorPoint,
                    (anchorPoint == "RIGHT" and spacing) or (anchorPoint == "LEFT" and -spacing) or 0,
                    (anchorPoint == "TOP" and spacing) or (anchorPoint == "BOTTOM" and -spacing) or 0
                )
            end

            lastFrame = frame

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

            if settings.customIndicator then
                -- Add settings for custom indicator
            else
                local size = 0.3 * settings.frameSize
                local fontPath, fontSize, fontFlags = frame.drIndicator.text:GetFont()

                frame.drIndicator:SetSize(size, size)
                frame.drIndicator.text:SetFont(fontPath, size, fontFlags)
            end

            if settings.cooldownNumbers then
                frame.cooldown:SetHideCountdownNumbers(false)
            else
                frame.cooldown:SetHideCountdownNumbers(true)
            end

            if settings.drIndicator then
                frame.drIndicator:SetAlpha(1)
            else
                frame.drIndicator:SetAlpha(0)
            end

            local borderSize = self.db.profile.units[unit].borderSize
            for name, tex in pairs(frame.borderTextures) do
                if name == "top" or name == "bottom" then
                    tex:SetHeight(borderSize)
                elseif name == "left" or name == "right" then
                    tex:SetWidth(borderSize)
                end
                if settings.coloredBorder then
                    tex:SetAlpha(1)
                else
                    tex:SetAlpha(0)
                end
            end

            if settings.enabled then
                frame:Show()
            else
                frame:Hide()
            end
        end
    end
end


function Icons:Test()
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
        local units = self.db.profile.units
        local drCategories = DRList:GetCategories()
        drCategories["taunt"] = nil
        local spellList = DRList:GetSpells()
        local reset = DRList:GetResetTime("stun")

        for drCategory in pairs(drCategories) do
            local spellID = GetRandomSpell(spellList, drCategory)
            for unitToken in pairs(units) do
                Icons.trackedPlayers = Icons.trackedPlayers or {}
                Icons.trackedPlayers[unitToken] = Icons.trackedPlayers[unitToken] or {}
                Icons.trackedPlayers[unitToken][drCategory] = Icons.trackedPlayers[unitToken][drCategory] or {}

                local currentTime = GetTime()
                local data = Icons.trackedPlayers[unitToken][drCategory]
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

        Icons.testTimer = C_Timer.NewTimer(reset, function()
            count = count + 1
            if count == 3 then
                Icons.trackedPlayers = {}
                count = 0
            end
            TestIcons()
        end)
    end


    if not Icons.testing then
        Icons.testing = true
        TestIcons()
    else
        Icons.testing = false
        Icons.trackedPlayers = {}
        if self.frames then
            for unit in pairs(self.frames) do
                for drCategory in pairs(self.frames[unit]) do
                    local frame = self.frames[unit][drCategory]
                    frame.active = false
                    frame:SetAlpha(0)
                end
            end
        end
        if Icons.testTimer then
            Icons.testTimer:Cancel()
            Icons.testTimer = nil
        end
    end
end


function Icons:ResetModule()
    if Icons.testing then
        self:Test()
    end
    self.db:ResetProfile()
    self:UpdateFrame()
end


function Icons:BuildGeneralOptions(unit)
    local anchorPointValues = {
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

    local name = string.upper(string.sub(unit, 1, 1)) .. string.sub(unit, 2)

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
                        self:UpdateFrame()
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
                        self:UpdateFrame()
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
                        self:UpdateFrame()
                    end,
                    order = 40,
                },
                cooldownNumbers = {
                    type = "toggle",
                    name = "Cooldown Numbers",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cooldownNumbers
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cooldownNumbers = value
                        self:UpdateFrame()
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
                        self:UpdateFrame()
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
                        self:UpdateFrame()
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
                        self:UpdateFrame()
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
                        self:UpdateFrame()
                    end,
                    order = 90,
                },
                separator3 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 100,
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
                        self:UpdateFrame()
                    end,
                    order = 109,
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
                        self:UpdateFrame()
                    end,
                    order = 110,
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
                growIcons = {
                    type = "select",
                    name = "Grow Direction",
                    desc = "Choose in which direction new icons will be shown",
                    values = {
                        ["Left"] = "Left",
                        ["Right"] = "Right",
                        ["Up"] = "Up",
                        ["Down"] = "Down"
                    },
                    get = function()
                        return self.db.profile.units[unit].growIcons
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].growIcons = value
                        self:UpdateFrame()
                    end,
                    order = 5,
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
                        self:UpdateFrame()
                    end,
                    order = 6,
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 10,
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
                        self:UpdateFrame()
                    end,
                    order = 15,
                },
                selectFrame = {
                    type = "execute",
                    name = "Select Frame",
                    desc = "Click on the frame that you want to select.",
                    func = function()
                        DRT:FrameSelector(function(selectedFrame)
                            self.db.profile.units[unit].anchorTo = selectedFrame
                            ACR:NotifyChange("DRT")
                            self:UpdateFrame()
                        end)
                    end,
                    order = 16,
                },
                separator2 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 20,
                },
                anchorPoint = {
                    type = "select",
                    name = "Anchor Frame Point",
                    desc = "Which point of the anchor frame to anchor to.",
                    values = anchorPointValues,
                    get = function()
                        return self.db.profile.units[unit].anchorPoint
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].anchorPoint = value
                        self:UpdateFrame()
                    end,
                    order = 25,
                },
                iconPoint = {
                    type = "select",
                    name = "Icon Frame Point",
                    desc = "Which point of the icon frame to anchor to.",
                    values = anchorPointValues,
                    get = function()
                        return self.db.profile.units[unit].iconPoint
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].iconPoint = value
                        self:UpdateFrame()
                    end,
                    order = 30,
                },
                separator3 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 35,
                },
                offsetX = {
                    type = "range",
                    name = "Icon Frame Offset X",
                    desc = "",
                    min = -100,
                    max = 100,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].offsetX
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].offsetX = value
                        self:UpdateFrame()
                    end,
                    order = 40,
                },
                offsetY = {
                    type = "range",
                    name = "Icon Frame Offset Y",
                    desc = "",
                    min = -100,
                    max = 100,
                    step = 1,
                    get = function ()
                        return self.db.profile.units[unit].offsetY
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].offsetY = value
                        self:UpdateFrame()
                    end,
                    order = 45,
                },
            }
        }

    }

    return generalOptions
end


function Icons:BuildDiminishingReturnsOptions(unit)
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

    local drCategories = DRList:GetCategories()
    drCategories["taunt"] = nil
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
                self:UpdateFrame()
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
                self:UpdateFrame()
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
                self:UpdateFrame()
            end,
            disabled = function ()
                return not self:IsEnabled() or not self.db.profile.units[unit].enabled
            end,
            order = 300 + self.db.profile.units[unit].categories[category].order,
        }
    end

    return diminishingReturnsOptions
end


function Icons:GetOptions()
    if not self.db then
        self:SetupDB()
    end

    local options = {
        type = "group",
        name = "Icons",
        childGroups = "tab",
        args = {
            isEnabled = {
                type = "toggle",
                name = "Enable Module",
                get = function()
                    return DRT.db.profile.modules["Icons"].enabled
                end,
                set = function(_, value)
                    DRT.db.profile.modules["Icons"].enabled = value
                    if value then
                        DRT:EnableModule("Icons")
                    else
                        DRT:DisableModule("Icons")
                    end
                end,
                order = 100
            },
            resetButton = {
                type = "execute",
				name = "Reset Module",
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

    local drCategories = DRList:GetCategories()
    drCategories["taunt"] = nil
    local count = 0
    for _ in pairs(drCategories) do
        count = count + 1
    end

    for unit in pairs(self.db.profile.units) do
        local name = string.upper(string.sub(unit, 1, 1)) .. string.sub(unit, 2)

        options.args[unit] = {
            type = "group",
            name = name,
            order = self.db.profile.units[unit].order,
            childGroups = "tab",
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable DR tracking for this unit",
                    get = function ()
                        return self.db.profile.units[unit].enabled
                    end,
                    set = function (_, value)
                        self.db.profile.units[unit].enabled = value
                        self:UpdateFrame()
                    end,
                    disabled = function ()
                        return not self:IsEnabled()
                    end,
                    order = 100,
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
