local MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
local Icons = MyAddon:NewModule("Icons")


function Icons:OnInitialize()
    self.db = MyAddon.db:RegisterNamespace("Icons", {
        profile = {
            enabled = true,
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
    print("Reset Module")
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
                    return Icons.db.profile.enabled
                end,
                set = function(_, value)
                    Icons.db.profile.enabled = value
                    if value then
                        Icons:Enable()
                    else
                        Icons:Disable()
                    end
                end,
                order = 1
            },
            resetButton = {
                type = "execute",
				name = "Reset Module",
				func = function ()
                    Icons:ResetModule()
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
