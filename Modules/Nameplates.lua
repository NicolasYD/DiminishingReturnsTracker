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
    self.visibleNameplates = self.visibleNameplates or {}
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

            -- General settings
            excludeFriendly = true,
            excludeHostile = false,
            excludeNPCs = false,
            excludePets = true,
            excludeGuardians = true,
            excludeObjects = true,

            -- Icon settings
            coloredBorder = true,
            drIndicator = true,
            cropIcons = true,
            growIcons = "RIGHT",
            iconsSpacing = 5,
            borderSize = 1,
            frameSize = 30,
            point = "CENTER",
            relativePoint = "BOTTOM",
            offsetX = 0,
            offsetY = 0,
            positionLocked = true,

            -- Cooldown settings
            cooldown = true,
            cooldownReverse = true,
            cooldownEdge = true,
            cooldownNumbersHide = false,
            cooldownSwipeAlpha = 0.6,
        }
    })
end


function NP:NAME_PLATE_UNIT_ADDED(_, nameplateUnit)
    local unitGUID = UnitGUID(nameplateUnit)
    local nameplateFrame = C_NamePlate.GetNamePlateForUnit(nameplateUnit)

    if not unitGUID or not nameplateFrame then return end

    self.visibleNameplates[nameplateFrame] = self.visibleNameplates[nameplateFrame] or {}
    self.visibleNameplates[nameplateFrame].unitGUID = unitGUID

    -- Create DR frames for nameplates if they don't exist yet
    if not self.unitContainers[nameplateFrame] then
        self:CreateFrames(nameplateFrame)
    end

    self.unitContainers[nameplateFrame]:SetAlpha(1)

    for drCategory, _ in pairs(drCategories) do
        self:StartOrUpdateDRTimer(drCategory, unitGUID)
    end
end


function NP:NAME_PLATE_UNIT_REMOVED(_, nameplateUnit)
    local nameplateFrame = C_NamePlate.GetNamePlateForUnit(nameplateUnit)

    if not nameplateFrame then return end

    self.visibleNameplates[nameplateFrame] = nil

    self:ResetFrame(nameplateFrame)
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

    -- Return if affected unit is excluded from tracking
    local settings = self.db.profile
    local isFriendly = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0
    local isHostile  = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    local isNPC = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0
    local isPet = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PET) > 0
    local isGuardian = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0
    local isObject = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_OBJECT) > 0

    if settings.excludeFriendly and isFriendly then return end
    if settings.excludeHostile and isHostile then return end
    if settings.excludeNPCs and isNPC then return end
    if settings.excludePets and isPet then return end
    if settings.excludeGuardians and isGuardian then return end
    if settings.excludeObjects and isObject then return end

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


function NP:CreateFrames(nameplateFrame)
    local nameplateName = nameplateFrame:GetName()

    local function CreateBorderTextures(parent)
        local border = {}

        border.left = parent:CreateTexture(nil, "OVERLAY")
        border.right = parent:CreateTexture(nil, "OVERLAY")
        border.top = parent:CreateTexture(nil, "OVERLAY")
        border.bottom = parent:CreateTexture(nil, "OVERLAY")

        return border
    end

    -- Create the container frame and store the reference
    local container = CreateFrame("Frame", "NPContainer." .. nameplateName, nameplateFrame)
    self.unitContainers[nameplateFrame] = container

    -- Create the container texture
    container.texture = container:CreateTexture(nil, "OVERLAY")

    -- Create the container text label
    container.text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    for drCategory, _ in pairs(drCategories) do

        -- Create the DR category frame and store the reference
        local frame = CreateFrame("Frame", "NPFrame." .. nameplateName .. "." .. drCategory, container)
        self.categoryFrames[nameplateFrame] = self.categoryFrames[nameplateFrame] or {}
        self.categoryFrames[nameplateFrame][drCategory] = frame

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

        -- Create the DR indicator border frame and textures
        frame.drIndicator.border = CreateFrame("Frame", nil, frame.drIndicator)
        frame.drIndicator.borderTextures = CreateBorderTextures(frame.drIndicator.border)
    end

    self:StyleFrames()
end



function NP:StyleFrames()
    local settings = self.db.profile

    local enabledFrameCount = 0
    for _, drSettings in pairs(settings.drCategories) do
        if drSettings.enabled then
            enabledFrameCount = enabledFrameCount + 1
        end
    end

    for nameplateFrame, container in pairs(self.unitContainers) do

        -- Container styling
        container:ClearAllPoints()
        container:SetPoint(settings.point, nameplateFrame, settings.relativePoint, settings.offsetX, settings.offsetY)
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
        if settings.positionLocked then
            container.texture:SetColorTexture(0, 0, 0, 0)
        else
            container.texture:SetDrawLayer("OVERLAY", 1)
            container.texture:SetColorTexture(0, 0, 0, 0.4)
        end

        -- Container text label styling
        container.text:ClearAllPoints()
        container.text:SetAllPoints()
        if settings.positionLocked then
            container.text:SetText("")
        else
            container.text:SetDrawLayer("OVERLAY", 2)
            if settings.growIcons == "LEFT" or settings.growIcons == "RIGHT" then
                container.text:SetText("DRT nameplate")
            elseif settings.growIcons == "UP" or settings.growIcons == "DOWN" then
                container.text:SetText("D\nR\nT\n\nn\na\nm\ne\np\nl\na\nt\ne")
            end
        end

        for drCategory, _ in pairs(drCategories) do
            local frame = self.categoryFrames[nameplateFrame][drCategory]

            -- DR category frame styling
            frame:SetSize(settings.frameSize, settings.frameSize)

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
            frame.cooldown:SetHideCountdownNumbers(settings.cooldownNumbersHide)

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
    end
end


function NP:UpdateFrames()
    if not self.categoryFrames then
        return
    end

    local settings = self.db.profile

    local growDirection = {
        LEFT = {iconPoint = "RIGHT", anchorPoint = "LEFT"},
        RIGHT = {iconPoint = "LEFT", anchorPoint = "RIGHT"},
        UP = {iconPoint = "BOTTOM", anchorPoint = "TOP"},
        DOWN = {iconPoint = "TOP", anchorPoint = "BOTTOM"},
    }

    for nameplateFrame, drCategory in pairs(self.categoryFrames) do
        local container = self.unitContainers[nameplateFrame]
        local activeFrames = {}
        local enabledFrameCount = 0

        for category, frame in pairs(drCategory) do
            frame.enabled = settings.drCategories[category].enabled

            if frame.enabled then
                enabledFrameCount = enabledFrameCount + 1
            end

            if frame.active and frame.enabled then
                table.insert(activeFrames, {
                    category = category,
                    frame = frame,
                    priority = settings.drCategories[category].priority,
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
            local iconPoint = growDirection[direction].iconPoint
            local anchorPoint = growDirection[direction].anchorPoint
            local spacing = settings.iconsSpacing
            frame:ClearAllPoints()
            if not lastFrame then
                frame:SetPoint(iconPoint, container)
            else
                frame:SetPoint(
                    iconPoint,
                    lastFrame,
                    anchorPoint,
                    (anchorPoint == "RIGHT" and spacing) or (anchorPoint == "LEFT" and -spacing) or 0,
                    (anchorPoint == "TOP" and spacing) or (anchorPoint == "BOTTOM" and -spacing) or 0
                )
            end
            lastFrame = frame
        end
    end
end


function NP:ResetFrame(nameplateFrame)
    local container = self.unitContainers[nameplateFrame]
    container:SetAlpha(0)

    local categoryFrames = self.categoryFrames[nameplateFrame]
    for _, categoryFrame in pairs(categoryFrames) do
        categoryFrame:SetAlpha(0)
        categoryFrame.icon:SetTexture(nil)
        categoryFrame.cooldown:Clear()
    end
end


function NP:StartOrUpdateDRTimer(drCategory, unitGUID, spellID)
    local tracked = self.trackedUnits[unitGUID]

    if not tracked then return end

    local data = self.trackedUnits[unitGUID][drCategory]

    if spellID then
        data.lastSpellID = spellID
    end

    local nameplateFrame
    for frame, frameData in pairs(self.visibleNameplates) do
        if frameData.unitGUID == unitGUID then
            nameplateFrame = frame
        end
    end

    local frame = self.categoryFrames[nameplateFrame] and self.categoryFrames[nameplateFrame][drCategory]
    local categoryIcon = self.db.profile.drCategories[drCategory].icon

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

        local text = diminishedText[data.diminished]
        local color = diminishedColor[data.diminished]

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
                NP:UpdateFrames()
            end
        end)
    end

    self:UpdateFrames()
end


function NP:Test()
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
        local spellList = DRList:GetSpells()
        local reset = DRList:GetResetTime("stun")

        for drCategory, _ in pairs(drCategories) do
            local spellID = GetRandomSpell(spellList, drCategory)
            for nameplateFrames, nameplateData in pairs(self.visibleNameplates) do
                local unitGUID = nameplateData.unitGUID
                NP.trackedUnits = NP.trackedUnits or {}
                NP.trackedUnits[unitGUID] = NP.trackedUnits[unitGUID] or {}
                NP.trackedUnits[unitGUID][drCategory] = NP.trackedUnits[unitGUID][drCategory] or {}

                local currentTime = GetTime()
                local data = NP.trackedUnits[unitGUID][drCategory]
                data.startTime = currentTime
                data.resetTime = DRList:GetResetTime(drCategory)
                data.expirationTime = data.startTime + data.resetTime

                if data.diminished == nil or currentTime >= (data.expirationTime or 0) then -- is nil or DR expired
                    local duration = 1
                    data.diminished = DRList:NextDR(duration, drCategory)
                else
                    data.diminished = DRList:NextDR(data.diminished, drCategory)
                end

                self:StartOrUpdateDRTimer(drCategory, unitGUID, spellID)
            end
        end

        NP.testTimer = C_Timer.NewTimer(reset, function()
            count = count + 1
            if count == 3 then
                NP.trackedUnits = {}
                count = 0
            end
            TestIcons()
        end)
    end


    if not NP.testing then
        NP.testing = true
        TestIcons()
    else
        NP.testing = false
        NP.trackedUnits = {}
        if self.categoryFrames then
            for nameplateUnit in pairs(self.categoryFrames) do
                for drCategory in pairs(self.categoryFrames[nameplateUnit]) do
                    local frame = self.categoryFrames[nameplateUnit][drCategory]
                    frame.active = false
                    frame:SetAlpha(0)
                end
            end
        end
        if NP.testTimer then
            NP.testTimer:Cancel()
            NP.testTimer = nil
        end
    end
end


function NP:ResetModule()
    self.db:ResetProfile()
    self:StyleFrames()
    self:UpdateFrames()
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
                order = 10
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
                order = 20
            },
            separator1 = {
                type = "description",
                name = "",
                width = "full",
                order = 30
            },
            general = {
                type = "group",
                name = "General",
                order = 40,
                args = {
                    widget = {
                        type = "group",
                        name = "Widget",
                        desc = "Widget settings",
                        inline = true,
                        disabled = function ()
                            return not self:IsEnabled()
                        end,
                        order = 10,
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
                                    return self.db.profile.cooldown
                                end,
                                set = function(_, value)
                                    self.db.profile.cooldown = value
                                    self:StyleFrames()
                                end,
                                order = 20,
                            },
                            cooldownReverse = {
                                type = "toggle",
                                name = "Cooldown Reverse",
                                desc = "",
                                get = function()
                                    return self.db.profile.cooldownReverse
                                end,
                                set = function(_, value)
                                    self.db.profile.cooldownReverse = value
                                    self:StyleFrames()
                                end,
                                order = 30,
                            },
                            cooldownEdge = {
                                type = "toggle",
                                name = "Cooldown Edge",
                                desc = "",
                                get = function()
                                    return self.db.profile.cooldownEdge
                                end,
                                set = function(_, value)
                                    self.db.profile.cooldownEdge = value
                                    self:StyleFrames()
                                end,
                                order = 40,
                            },
                            cooldownNumbersHide = {
                                type = "toggle",
                                name = "Cooldown Numbers",
                                desc = "",
                                get = function()
                                    return self.db.profile.cooldownNumbersHide
                                end,
                                set = function(_, value)
                                    self.db.profile.cooldownNumbersHide = value
                                    self:StyleFrames()
                                end,
                                order = 50,
                            },
                            separator1 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 60,
                            },
                            cooldownSwipeAlpha = {
                                type = "range",
                                name = "Cooldown Swipe Alpha",
                                desc = "",
                                min = 0,
                                max = 1,
                                step = 0.1,
                                get = function()
                                    return self.db.profile.cooldownSwipeAlpha
                                end,
                                set = function(_, value)
                                    self.db.profile.cooldownSwipeAlpha = value
                                    self:StyleFrames()
                                end,
                                order = 70,
                            },
                            separator2 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 80,
                            },
                            header2 = {
                            type = "header",
                            name = "Icon Options",
                            width = "full",
                            order = 90,
                            },
                            coloredBorder = {
                                type = "toggle",
                                name = "Colored Border",
                                desc = "Show a colored border that indicates the DR level",
                                get = function()
                                    return self.db.profile.coloredBorder
                                end,
                                set = function(_, value)
                                    self.db.profile.coloredBorder = value
                                    self:StyleFrames()
                                end,
                                order = 100,
                            },
                            drIndicator = {
                                type = "toggle",
                                name = "DR Indicator",
                                desc = "Show an indicator for the DR level",
                                get = function()
                                    return self.db.profile.drIndicator
                                end,
                                set = function(_, value)
                                    self.db.profile.drIndicator = value
                                    self:StyleFrames()
                                end,
                                order = 110,
                            },
                            cropIcons = {
                                type = "toggle",
                                name = "Crop Icons",
                                desc = "",
                                get = function()
                                    return self.db.profile.cropIcons
                                end,
                                set = function(_, value)
                                    self.db.profile.cropIcons = value
                                    self:StyleFrames()
                                end,
                                order = 120,
                            },
                            separator3 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 130,
                            },
                            growIcons = {
                                type = "select",
                                name = "Grow Direction",
                                desc = "Choose in which direction new icons will be shown",
                                values = {
                                    ["LEFT"] = "Left",
                                    ["RIGHT"] = "Right",
                                    ["UP"] = "Up",
                                    ["DOWN"] = "Down"
                                },
                                get = function()
                                    return self.db.profile.growIcons
                                end,
                                set = function(_, value)
                                    self.db.profile.growIcons = value
                                    self:StyleFrames()
                                    self:UpdateFrames()
                                end,
                                order = 140,
                            },
                            iconsSpacing = {
                                type = "range",
                                name = "Icon Spacing",
                                desc = "Adjust the gap between the icons",
                                min = 0,
                                max = 200,
                                step = 1,
                                get = function ()
                                    return self.db.profile.iconsSpacing
                                end,
                                set = function (_, value)
                                    self.db.profile.iconsSpacing = value
                                    self:StyleFrames()
                                    self:UpdateFrames()
                                end,
                                order = 150,
                            },
                            separator4 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 160,
                            },
                            borderSize = {
                                type = "range",
                                name = "Colored Border Size",
                                desc = "",
                                min = 1,
                                max = 20,
                                step = 1,
                                get = function ()
                                    return self.db.profile.borderSize
                                end,
                                set = function (_, value)
                                    self.db.profile.borderSize = value
                                    self:StyleFrames()
                                end,
                                order = 170,
                            },
                            frameSize = {
                                type = "range",
                                name = "Icons Frame Size",
                                desc = "",
                                min = 0,
                                max = 200,
                                step = 1,
                                get = function ()
                                    return self.db.profile.frameSize
                                end,
                                set = function (_, value)
                                    self.db.profile.frameSize = value
                                    self:StyleFrames()
                                end,
                                order = 180,
                            },
                        },
                    },
                    position = {
                        type = "group",
                        name = "Position",
                        desc = "Position settings",
                        inline = true,
                        disabled = function ()
                            return not self:IsEnabled()
                        end,
                        order = 20,
                        args = {
                            lockPosition = {
                                type = "toggle",
                                name = "Lock Position",
                                desc = "If unlocked, icons can be moved by mouse.",
                                get = function()
                                    return self.db.profile.positionLocked
                                end,
                                set = function(_, value)
                                    self.db.profile.positionLocked = value
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
                            point = {
                                type = "select",
                                name = "Anchor Frame Point",
                                desc = "Which point of the anchor frame to anchor to.",
                                values = {
                                    ["TOP"] = "TOP",
                                    ["TOPLEFT"] = "TOPLEFT",
                                    ["TOPRIGHT"] = "TOPRIGHT",
                                    ["LEFT"] = "LEFT",
                                    ["CENTER"] = "CENTER",
                                    ["RIGHT"] = "RIGHT",
                                    ["BOTTOM"] = "BOTTOM",
                                    ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                },
                                get = function()
                                    return self.db.profile.point
                                end,
                                set = function(_, value)
                                    self.db.profile.point = value
                                    self:StyleFrames()
                                end,
                                order = 30,
                            },
                            relativePoint = {
                                type = "select",
                                name = "Icon Frame Point",
                                desc = "Which point of the icon frame to anchor to.",
                                values = {
                                    ["TOP"] = "TOP",
                                    ["TOPLEFT"] = "TOPLEFT",
                                    ["TOPRIGHT"] = "TOPRIGHT",
                                    ["LEFT"] = "LEFT",
                                    ["CENTER"] = "CENTER",
                                    ["RIGHT"] = "RIGHT",
                                    ["BOTTOM"] = "BOTTOM",
                                    ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                },
                                get = function()
                                    return self.db.profile.relativePoint
                                end,
                                set = function(_, value)
                                    self.db.profile.relativePoint = value
                                    self:StyleFrames()
                                end,
                                order = 40,
                            },
                            separator3 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 50,
                            },
                            offsetX = {
                                type = "range",
                                name = "Icon Frame Offset X",
                                desc = "",
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function ()
                                    return self.db.profile.offsetX
                                end,
                                set = function (_, value)
                                    self.db.profile.offsetX = value
                                    self:StyleFrames()
                                end,
                                order = 60,
                            },
                            offsetY = {
                                type = "range",
                                name = "Icon Frame Offset Y",
                                desc = "",
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function ()
                                    return self.db.profile.offsetY
                                end,
                                set = function (_, value)
                                    self.db.profile.offsetY = value
                                    self:StyleFrames()
                                end,
                                order = 70,
                            },
                        }
                    }
                }
            },
            diminishingReturns = {
                type = "group",
                name = "DRs",
                order = 50,
                args = {
                    trackedUnits = {
                        type = "group",
                        name = "Tracked Units",
                        inline = true,
                        disabled = function ()
                            return not self:IsEnabled()
                        end,
                        order = 10,
                        args = {
                            header1 = {
                                type = "header",
                                name = "Excluded Units",
                                width = "full",
                                order = 10,
                            },
                            excludeFriendly = {
                                type = "toggle",
                                name = "Exclude Friendly",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludeFriendly
                                end,
                                set = function(_, value)
                                    self.db.profile.excludeFriendly = value
                                end,
                                order = 20,
                            },
                            excludeHostile = {
                                type = "toggle",
                                name = "Exclude Hostile",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludeHostile
                                end,
                                set = function(_, value)
                                    self.db.profile.excludeHostile = value
                                end,
                                order = 30,
                            },
                            excludeNPCs = {
                                type = "toggle",
                                name = "Exclude NPCs",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludeNPCs
                                end,
                                set = function(_, value)
                                    self.db.profile.excludeNPCs = value
                                end,
                                order = 40,
                            },
                            excludePets = {
                                type = "toggle",
                                name = "Exclude Pets",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludePets
                                end,
                                set = function(_, value)
                                    self.db.profile.excludePets = value
                                end,
                                order = 50,
                            },
                            excludeGuardians = {
                                type = "toggle",
                                name = "Exclude Guardians",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludeGuardians
                                end,
                                set = function(_, value)
                                    self.db.profile.excludeGuardians = value
                                end,
                                order = 60,
                            },
                            excludeObjects = {
                                type = "toggle",
                                name = "Exclude Objects",
                                desc = "",
                                get = function()
                                    return self.db.profile.excludeObjects
                                end,
                                set = function(_, value)
                                    self.db.profile.excludeObjects = value
                                end,
                                order = 70,
                            },
                        }
                    },
                }
            },
        }
    }

    return options
end
