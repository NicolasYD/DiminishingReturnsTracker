local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local Icons = DRT:NewModule("Icons", "AceEvent-3.0")

local DRList = LibStub("DRList-1.0")

function Icons:OnInitialize()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")

    if not self.db then
        self:SetupDB()
    end

    self.trackedPlayers = {}
end


function Icons:OnEnable()
    local drCategories = DRList:GetCategories()
    for unit in pairs(self.db.profile.units) do
        for drCategory in pairs(drCategories) do
            self:CreateFrame(unit, drCategory)
        end
    end
    self:UpdateFrame()
end


function Icons:OnDisable()
    if self.frames then
        for unit in pairs(self.frames) do
            for category in pairs(self.frames[unit]) do
                self.frames[unit][category]:Hide()
            end
        end
    end
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
            priority = 8,
            order = 1,
            icon = "dynamic",
            enabled = true,
        },
        disorient = {
            priority = 7,
            order = 2,
            icon = "dynamic",
            enabled = true,
        },
        incapacitate = {
            priority = 6,
            order = 3,
            icon = "dynamic",
            enabled = true,
        },
        silence = {
            priority = 5,
            order = 4,
            icon = "dynamic",
            enabled = false,
        },
        disarm = {
            priority = 4,
            order = 5,
            icon = "dynamic",
            enabled = false,
        },
        knockback = {
            priority = 3,
            order = 6,
            icon = "dynamic",
            enabled = false,
        },
        root = {
            priority = 2,
            order = 7,
            icon = "dynamic",
            enabled = false,
        },
        taunt = {
            priority = 1,
            order = 8,
            icon = "dynamic",
            enabled = false,
        },
    }

    self.db = DRT.db:RegisterNamespace("Icons", {
        profile = {
            units = {
                player = {
                    enabled = true,
                    cropIcons = true,
                    frameSize = 30,
                    iconPoint = "TOP",
                    anchorTo = "PlayerFrame",
                    anchorPoint = "TOPRIGHT",
                    offsetX = -35,
                    offsetY = 5,
                    growIcons = "Left",
                    iconsSpacing = 5,
                    cooldown = true,
                    cooldownReverse = true,
                    cooldownSwipeAlpha = 0.5,
                    cooldownEdge = true,
                    categories = defaultCategories
                },
                target = {
                    enabled = true,
                    cropIcons = true,
                    frameSize = 30,
                    iconPoint = "TOP",
                    anchorTo = "TargetFrame",
                    anchorPoint = "TOPLEFT",
                    offsetX = 35,
                    offsetY = 5,
                    growIcons = "Right",
                    iconsSpacing = 5,
                    cooldown = true,
                    cooldownReverse = true,
                    cooldownSwipeAlpha = 0.5,
                    cooldownEdge = true,
                    categories = defaultCategories
                },
            },
        },
    })
end


function Icons:CreateFrame(unit, category)
    self.frames = self.frames or {}
    self.frames[unit] = self.frames[unit] or {}

    if self.frames[unit][category] then
        return
    end

    local frame = CreateFrame("Frame", unit..category, UIParent)
    self.frames[unit][category] = frame

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()

    -- Cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    -- Text label
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("BOTTOMRIGHT", -2, 2)
end


function Icons:COMBAT_LOG_EVENT_UNFILTERED()
    if Icons.testing then return end

    local _, eventType, _, _, _, _, _, destGUID, _, destFlags, _, spellID, _, _, auraType = CombatLogGetCurrentEventInfo()

    -- Check all debuffs found in the combat log
    if auraType == "DEBUFF" then
        -- Get the DR category or exit immediately if current debuff doesn't have a DR
        local category, sharedCategories = DRList:GetCategoryBySpellID(spellID)
        if not category then return end

        -- Check if unit that got the debuff is a player
        -- You might also want to check if it's a hostile or friendly unit depending on your needs
        local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
        --if not isPlayer then return end
        -- for PvE too: 
        if not isPlayer and not DRList:IsPvECategory(category) then return end

        -- The debuff has faded or refreshed, DR timer starts
        if eventType == "SPELL_AURA_REMOVED" or eventType == "SPELL_AURA_REFRESH" then
            --local unitID = UnitTokenFromGUID(destGUID)

            -- Trigger main DR category
            self:StartOrUpdateDRTimer(category, destGUID, spellID)

            -- Trigger any shared DR categories
            if sharedCategories then
                for i = 1, #sharedCategories do
                    if sharedCategories[i] ~= category then
                        self:StartOrUpdateDRTimer(sharedCategories[i], destGUID, spellID)
                    end
                end
            end
        end
    end
end


function Icons:PLAYER_TARGET_CHANGED()
    if Icons.testing then return end

    local targetGUID = UnitGUID("target")
    if not targetGUID then return end

    local tracked = self.trackedPlayers and self.trackedPlayers[targetGUID]
    local unitToken = "target"

    if not tracked then
        local frames = self.frames[unitToken]
        for _, frame in pairs(frames) do
            if frame then
                frame:Hide()
            end
        end
        return
    end

    for drCategory, data in pairs(tracked) do
        local frame = self.frames[unitToken][drCategory]
        if data.expirationTime and GetTime() < data.expirationTime then
            if frame then
                local categoryIcon = self.db.profile.units[unitToken].categories[drCategory].icon
                local iconTexture

                if categoryIcon == "dynamic" then
                    local spellInfo = C_Spell.GetSpellInfo(data.lastSpellID)
                    iconTexture = spellInfo and spellInfo.originalIconID
                else
                    local spellInfo = C_Spell.GetSpellInfo(categoryIcon)
                    iconTexture = spellInfo and spellInfo.originalIconID
                end

                if iconTexture then
                    frame:Show()
                    frame.icon:SetTexture(iconTexture)
                    frame.active = true
                    local duration = data.expirationTime - GetTime()
                    frame.cooldown:Clear()
                    frame.cooldown:SetCooldown(data.startTime, data.resetTime)
                    self:ResetDRTimer(targetGUID, drCategory, unitToken, duration)
                    self:UpdateFrame()
                end
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
    -- Table for storing all DRs
    local trackedPlayers = self.trackedPlayers

    -- Create or update DR tables for unit
    trackedPlayers[unitGUID] = trackedPlayers[unitGUID] or {}
    trackedPlayers[unitGUID][drCategory] = trackedPlayers[unitGUID][drCategory] or {}

    local data = trackedPlayers[unitGUID][drCategory]
    data.lastSpellID = spellID

    local time = GetTime()
    data.startTime = time
    data.resetTime = DRList:GetResetTime(drCategory)

    -- Set DR category expiration time
    data.expirationTime = data.startTime + data.resetTime

    -- Set how many times the DR category has been applied so far
    if data.diminished == nil or time >= (data.expirationTime or 0) then -- is nil or DR expired
        data.diminished = 1
    else
        data.diminished = DRList:NextDR(data.diminished, drCategory)
    end

    self:ShowDRTimer(drCategory, unitGUID)
end


function Icons:ShowDRTimer(drCategory, unitGUID)
    -- Do your stuff here, start a frame timer, etc.
    local trackedPlayers = self.trackedPlayers
    local data = trackedPlayers[unitGUID][drCategory]
    local unitTokens
    if Icons.testing then
        unitTokens = {unitGUID}
    else
        unitTokens = self:GetUnitTokens(unitGUID)
    end

    for _, unitToken in ipairs(unitTokens) do
        local frame = self.frames[unitToken][drCategory]
        local categoryIcon = self.db.profile.units[unitToken].categories[drCategory].icon

        local iconTexture
        if categoryIcon == "dynamic" then
            local spellInfo = C_Spell.GetSpellInfo(data.lastSpellID)
            iconTexture = spellInfo.originalIconID
        else
            local spellInfo = C_Spell.GetSpellInfo(categoryIcon)
            iconTexture = spellInfo.originalIconID
        end


        frame:Show()
        frame.active = true

        frame.icon:SetTexture(iconTexture)

        frame.cooldown:SetCooldown(data.startTime, data.resetTime)
        self:UpdateFrame()
        self:ResetDRTimer(unitGUID, drCategory, unitToken, data.resetTime)
    end
end


function Icons:ResetDRTimer(unitGUID, drCategory, unitToken, resetIn)
    local trackedPlayers = self.trackedPlayers
    local data = trackedPlayers[unitGUID][drCategory]
    local frame = self.frames[unitToken][drCategory]

    if not frame then return end

    -- Remove any existing OnUpdate script
    frame:SetScript("OnUpdate", nil)

    -- Store expiration time
    local expirationTime = GetTime() + resetIn
    frame.expirationTime = expirationTime

    frame:SetScript("OnUpdate", function(self)
        if GetTime() >= data.expirationTime then
            self:SetScript("OnUpdate", nil)
            self.active = false
            self:Hide()
            self.cooldown:Clear()

            -- Clear the tracked DR data
            local trackedData = trackedPlayers[unitGUID]
            if trackedData then
                trackedData[drCategory] = nil
                if next(trackedData) == nil then
                    trackedPlayers[unitGUID] = nil
                end
            end

            Icons:UpdateFrame()
        end
    end)
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

            if frame.active then
                table.insert(activeFrames, {
                    category = category,
                    frame = frame,
                    priority = self.db.profile.units[unit].categories[category].priority,
                })
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

            if settings.enabled and frame.enabled then
                frame:Show()
            else
                frame:Hide()
            end
        end
    end
end


function Icons:Test()
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
        local categories = DRList:GetCategories()
        local spellList = DRList:GetSpells()

        for category in pairs(categories) do
            local spellID = GetRandomSpell(spellList, category)
            for unit in pairs(units) do
                self:StartOrUpdateDRTimer(category, unit, spellID)
            end
        end
    end

    if not Icons.testing then
        Icons.testing = true
        TestIcons()
    else
        Icons.testing = false
        if self.frames then
            for unit in pairs(self.frames) do
                for category in pairs(self.frames[unit]) do
                    self.frames[unit][category]:Hide()
                end
            end
        end
    end
end


function Icons:ResetModule()
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
                order = 1,
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
                    order = 2,
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
                    order = 3,
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
                    order = 4,
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 5,
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
                    order = 6,
                },
                separator2 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 7,
                },
                header2 = {
                type = "header",
                name = "Icon Options",
                width = "full",
                order = 8,
                },
                cropIcons = {
                    type = "toggle",
                    name = "Icons Border Crop",
                    desc = "",
                    get = function()
                        return self.db.profile.units[unit].cropIcons
                    end,
                    set = function(_, value)
                        self.db.profile.units[unit].cropIcons = value
                        self:UpdateFrame()
                    end,
                    order = 9,
                },
                separator3 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 10,
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
                    order = 11,
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
    local count = 0
    for _ in pairs(drCategories) do
        count = count + 1
    end

    for unit in pairs(self.db.profile.units) do
        local name = string.upper(string.sub(unit, 1, 1)) .. string.sub(unit, 2)

        options.args[unit] = {
            type = "group",
            name = name,
            order = 2,
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
