local MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")

-- Defines and registers the addon’s options for use in the Blizzard interface options
function MyAddon:SetupOptions()
	self.options = {
		type = "group",
		args = {
			test = {
				type = "execute",
				name = "Toggle Test Mode",
				order = 1,
				func = function()
					-- test mode function
				end
			},
			general = {
				type = "group",
				name = "General",
				desc = "General settings",
				order = 2,
				args = {
					general = {
						type = "group",
						name = "General",
						desc = "General settings",
						inline = true,
						order = 1,
						args = {
						-- all your option entries here
						}
					}
				}
			}
		}
	}

  	LibStub("AceConfig-3.0"):RegisterOptionsTable("MyAddon", self.options)
  	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyAddon", "MyAddon")
end
