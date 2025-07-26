local MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
local Icons = MyAddon:NewModule("Icons")


function Icons:OnInitialize()
    self.db = MyAddon.db:RegisterNamespace("Icons", {
        profile = {
            -- defaults
        }
    })

    print("Icons initialized")
end


function Icons:OnEnable()
    print("Icons enabled")
end


function Icons:OnDisable()
    print("Icons disabled")
end


function Icons:ResetModule()
    self.db:ResetProfile()
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
                    return MyAddon.db.profile.modules["Icons"].enabled
                end,
                set = function(_, value)
                    MyAddon.db.profile.modules["Icons"].enabled = value
                    if value then
                        self:Enable()
                    else
                        self:Disable()
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
            -- Add other module-specific settings here
        }
    }
end
