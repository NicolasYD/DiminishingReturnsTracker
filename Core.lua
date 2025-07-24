-- Create a new addon object using AceAddon-3.0 and include AceConsole-3.0 for chat commands
MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0")


-- Called when the addon is first loaded (before it is enabled)
function MyAddon:OnInitialize()
    -- Create a new database using AceDB-3.0 with default profile settings
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", {
        profile = {
            enabled = true
        }
    })

    -- Set up the addon configuration options
    self:SetupOptions()
end


-- Called when the addon is enabled (e.g., when logging in or reloading UI)
function MyAddon:OnEnable()
    -- Register slash commands to open the configuration panel
    self:RegisterChatCommand("drt", "OpenOptions")
    self:RegisterChatCommand("diminishingreturnstracker", "OpenOptions")
end


-- Called when the addon is disabled
function MyAddon:OnDisable()
    
end


-- Opens the configuration window for the addon when the slash command is used
function MyAddon:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open("MyAddon")
end
