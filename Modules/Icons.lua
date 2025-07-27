local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local Icons = DRT:NewModule("Icons")


function Icons:OnInitialize()
    self.db = DRT.db:RegisterNamespace("Icons", {
        profile = {
            cropIcons = false,
            frameSize = 30,
            iconPoint = "TOPRIGHT",
            anchorTo = "PlayerFrame",
            anchorPoint = "TOPRIGHT",
            offsetX = 0,
            offsetY = 0,
        }
    })

    self:CreateFrame("player") -- create frame for development purposes (delete later)

    print("Icons initialized")
end


function Icons:OnEnable()
    if self.frame then
        self.frame:Show()
    end
    print("Icons enabled")
end


function Icons:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
    print("Icons disabled")
end


function Icons:CreateFrame(unit)
    local frame = CreateFrame("Frame", "DRT" .. self.name .. "Frame" .. unit, UIParent)
    self.frame = frame

    -- Frame settings
    local settings = self.db.profile
    frame:SetSize(settings.frameSize, settings.frameSize)
    frame:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)

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
    frame.text:SetText("1")
end


function Icons:UpdateFrame()
    if not self.frame then
        return
    end

    local settings = self.db.profile

    self.frame:SetSize(settings.frameSize, settings.frameSize)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(settings.iconPoint, settings.anchorTo, settings.anchorPoint, settings.offsetX, settings.offsetY)
    if settings.cropIcons then
        self.frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        self.frame.icon:SetTexCoord(0, 1, 0, 1)
    end
end


function Icons:ResetModule()
    self.db:ResetProfile()
    self:UpdateFrame()
    print("Reset module")
end


function Icons:BuildIconOptions()
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

    local iconOptions = {
        widget = {
            type = "group",
            name = "Widget",
            desc = "Widget settings",
            inline = true,
            disabled = function ()
                return not self:IsEnabled()
            end,
            order = 6,
            args = {
                cropIcons = {
                    type = "toggle",
                    name = "Icons Border Crop",
                    desc = "",
                    get = function()
                        return self.db.profile.cropIcons
                    end,
                    set = function(_, value)
                        self.db.profile.cropIcons = value
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
                        return self.db.profile.frameSize
                    end,
                    set = function (_, value)
                        self.db.profile.frameSize = value
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
                return not self:IsEnabled()
            end,
            order = 7,
            args = {
                anchorTo = {
                    type = "input",
                    name = "Anchor Frame Name",
                    desc = "Enter the name of the frame to anchor this icon to.\nExample: PlayerFrameHealthBar",
                    get = function()
                        return self.db.profile.anchorTo or ""
                    end,
                    set = function(_, value)
                        self.db.profile.anchorTo = value
                        self:UpdateFrame()
                    end,
                    order = 1,
                },
                separator1 = {
                    type = "description",
                    name = "",
                    width = "full",
                    order = 5
                },
                anchorPoint = {
                    type = "select",
                    name = "Anchor Frame Point",
                    desc = "Which point of the anchor frame to anchor to.",
                    values = anchorPointValues,
                    get = function()
                        return self.db.profile.anchorPoint
                    end,
                    set = function(_, value)
                        self.db.profile.anchorPoint = value
                        self:UpdateFrame()
                    end,
                    order = 6,
                },
                iconPoint = {
                    type = "select",
                    name = "Icon Frame Point",
                    desc = "Which point of the icon frame to anchor to.",
                    values = anchorPointValues,
                    get = function()
                        return self.db.profile.iconPoint
                    end,
                    set = function(_, value)
                        self.db.profile.iconPoint = value
                        self:UpdateFrame()
                    end,
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
                        return self.db.profile.offsetX
                    end,
                    set = function (_, value)
                        self.db.profile.offsetX = value
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
                        return self.db.profile.offsetY
                    end,
                    set = function (_, value)
                        self.db.profile.offsetY = value
                        self:UpdateFrame()
                    end,
                    order = 9,
                },
            }
        }
    }
    return iconOptions
end


function Icons:GetOptions()
    return {
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
                order = 5
            },
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = self:BuildIconOptions()
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
end
