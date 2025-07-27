local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local Icons = DRT:NewModule("Icons")


function Icons:OnInitialize()
    self.frames = self.frames or {}

    if not self.db then
        self:SetupDB()
    end
    for unit in pairs(self.db.profile.units) do
        self:CreateFrame(unit)
    end
end


function Icons:OnEnable()
    self:UpdateFrame()
end


function Icons:OnDisable()
    if self.frames then
        for unit in pairs(self.frames) do
            self.frames[unit]:Hide()
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
                },
                target = {
                    enabled = false,
                    cropIcons = true,
                    frameSize = 30,
                    iconPoint = "TOP",
                    anchorTo = "TargetFrame",
                    anchorPoint = "TOPLEFT",
                    offsetX = 35,
                    offsetY = 5,
                },
            },
        },
    })
end


function Icons:CreateFrame(unit)
    local frame = CreateFrame("Frame", "DRT" .. self.name .. "Frame" .. unit, UIParent)
    self.frames[unit] = frame

    -- Frame settings
    local settings = self.db.profile.units[unit]
    frame:SetSize(settings.frameSize, settings.frameSize)
    frame:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()
    if settings.cropIcons then
        self.frames[unit].icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        self.frames[unit].icon:SetTexCoord(0, 1, 0, 1)
    end

    frame.icon:SetTexture("Interface\\Icons\\INV_Jewelry_Necklace_38") -- set texture for development purposes (delete later)

    -- Cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    -- Text label
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.text:SetText("1")
end


function Icons:UpdateFrame()
    if not self.frames then
        return
    end

    for unit in pairs(self.frames) do
        local settings = self.db.profile.units[unit]
        self.frames[unit]:SetSize(settings.frameSize, settings.frameSize)
        self.frames[unit]:ClearAllPoints()
        self.frames[unit]:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)
        if settings.cropIcons then
            self.frames[unit].icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        else
            self.frames[unit].icon:SetTexCoord(0, 1, 0, 1)
        end
        if settings.enabled then
            self.frames[unit]:Show()
        else
            self.frames[unit]:Hide()
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
                        order = 1
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
                        order = 2,
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
                    anchorTo = {
                        type = "input",
                        name = "Anchor Frame Name",
                        desc = "Enter the name of the frame to anchor this icon to.\nExample: PlayerFrameHealthBar",
                        get = function()
                            return self.db.profile.units[unit].anchorTo or ""
                        end,
                        set = function(_, value)
                            self.db.profile.units[unit].anchorTo = value
                            self:UpdateFrame()
                        end,
                        order = 1,
                    },
                    separator1 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 2
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
                        order = 3,
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
                        order = 4,
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
                        order = 5,
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
                        order = 6,
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
