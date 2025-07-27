local DRT = LibStub("AceAddon-3.0"):GetAddon("DRT")
local Icons = DRT:NewModule("Icons")


function Icons:OnInitialize()
    self.db = DRT.db:RegisterNamespace("Icons", {
        profile = {
            cropIcons = false,
            frameSize = 50,
            setPoint = "CENTER",
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
    frame:SetPoint(settings.setPoint)

    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()

    frame.icon:SetTexture("Interface\\Icons\\INV_Jewelry_Necklace_38") -- set texture for development purposes (delete later)

    -- Cooldown spiral
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    -- Text label
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("BOTTOM", 0, 2)
    frame.text:SetText("Test")
end


function Icons:UpdateFrame()
    if not self.frame then
        return
    end

    local settings = self.db.profile

    self.frame:SetSize(settings.frameSize, settings.frameSize)
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


function Icons:GetOptions()
    return {
        type = "group",
        name = "Icons",
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
                            if self.frame and self.frame.icon then
                                if value then
                                    self.frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                                else
                                    self.frame.icon:SetTexCoord(0, 1, 0, 1)
                                end
                            end
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
                            if self.frame then
                                self.frame:SetSize(value, value)
                            end
                        end,
                        order = 2,
                    },
                },
            },
            -- Add other module-specific settings here
        }
    }
end
