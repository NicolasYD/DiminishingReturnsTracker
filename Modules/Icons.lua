local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local Icons = DRT:NewModule("Icons")

local DRList = LibStub("DRList-1.0")

function Icons:OnInitialize()
    if not self.db then
        self:SetupDB()
    end
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
                    cooldown = true,
                    cooldownReverse = true,
                    cooldownSwipeAlpha = 0.5,
                    cooldownEdge = true,
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
                    cooldown = true,
                    cooldownReverse = true,
                    cooldownSwipeAlpha = 0.5,
                    cooldownEdge = true,
                },
            },
        },
    })
end


function Icons:CreateFrame(unit, category)
    self.frames = self.frames or {}
    self.frames[unit] = self.frames[unit] or {}
    self.frames[unit][category] = self.frames[unit][category] or {}

    local frame = CreateFrame("Frame", unit..category, UIParent)
    self.frames[unit][category] = frame

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()

    frame.icon:SetTexture("Interface\\Icons\\INV_Jewelry_Necklace_38") -- set texture for development purposes (delete later)

    -- Cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    -- Text label
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("BOTTOMRIGHT", -2, 2)
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
        local lastFrame
        for category in pairs(self.frames[unit]) do
            local frame = self.frames[unit][category]
            local settings = self.db.profile.units[unit]
            frame:SetSize(settings.frameSize, settings.frameSize)
            frame:ClearAllPoints()
            if not lastFrame then
                frame:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)
            else
                local direction = settings.growIcons
                local iconPoint = growDirection[direction].iconPoint
                local anchorPoint = growDirection[direction].anchorPoint
                frame:SetPoint(iconPoint, lastFrame, anchorPoint)
            end
            lastFrame = frame

            if settings.cropIcons then
                frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                frame.icon:SetTexCoord(0, 1, 0, 1)
            end

            frame.cooldown:SetDrawSwipe(settings.cooldown)
            frame.cooldown:SetReverse(settings.cooldownReverse)
            frame.cooldown:SetSwipeColor(0, 0, 0, settings.cooldownSwipeAlpha)
            frame.cooldown:SetDrawEdge(settings.cooldown and settings.cooldownEdge)

            if settings.enabled then
                frame:Show()
            else
                frame:Hide()
            end
        end
    end
end


function Icons:ResetModule()
    self.db:ResetProfile()
    self:UpdateFrame()
end


function Icons:BuildIconOptions(unit)
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

    local iconOptions = {
        type = "group",
        name = name,
        desc = "DR tracking for " .. unit .. " frame",
        order = 2,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                desc = "Enable DR tracking for this frame",
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
                order = 1,
            },
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
                        order = 1,
                    },
                    separator1 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 2,
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
                        order = 3,
                    },
                    separator2 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 4,
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
                        order = 5,
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
                        order = 6,
                    },
                    separator3 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 7,
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
                        order = 8,
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
                        order = 9,
                    },
                }
            }
        }
    }

    return iconOptions
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
                order = 1
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
                order = 2
            },
            separator1 = {
                type = "description",
                name = "",
                width = "full",
                order = 3
            },
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    header = {
                    type = "header",
                    name = "Units to track",
                    order = 1,
                    },
                }
            },
            diminishingReturns = {
                type = "group",
                name = "DRs",
                order = 2,
                args = {

                }
            },
        }
    }

    for unit in pairs(self.db.profile.units) do
        options.args.general.args[unit] = self:BuildIconOptions(unit)
    end

    return options
end
