NugRunningGUI = CreateFrame("Frame","NugRunningGUI")

-- NugRunningGUI:SetScript("OnEvent", function(self, event, ...)
	-- self[event](self, event, ...)
-- end)
-- NugRunningGUI:RegisterEvent("ADDON_LOADED")

local AceGUI = LibStub("AceGUI-3.0")
local COMBATLOG_OBJECT_AFFILIATION_PARTY_OR_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID + COMBATLOG_OBJECT_AFFILIATION_PARTY



function NugRunningGUI.SlashCmd(msg)
    NugRunningGUI.frame:Show()
end

local sortfunc = function(a,b)
	if a.order == b.order then
		return a.value < b.value
	else
		return a.order < b.order
	end
end
function NugRunningGUI.GenerateCategoryTree(self, isGlobal, category)
	local _,class = UnitClass("player")
	local custom = isGlobal and NugRunningConfigCustom["GLOBAL"] or NugRunningConfigCustom[class]

	local t = {}
	for spellID, opts in pairs(NugRunningConfigMerged[category]) do
		if (isGlobal and opts.global) or (not isGlobal and not opts.global) then
			local name = (opts.name == "" or not opts.name) and GetSpellInfo(spellID) or opts.name
			local custom_opts = custom[category] and custom[category][spellID]
			local status
			local order = 5
			-- print(opts.name, custom_opts)
			if not custom_opts or not next(custom_opts) then
				status = nil
			elseif custom_opts["disabled"] then
				status = "|cffff0000[D] |r"
				order = 6
			elseif not NugRunningConfig[category][spellID] then
				status = "|cff33ff33[A] |r"
				order = 1
			else
				status = "|cffffaa00[M] |r"
				order = 2
			end
			local text = status and status..name or name
			table.insert(t, {
				value = spellID,
				text = text,
				icon = GetSpellTexture(spellID),
				order = order,
			})
		end
	end
	table.sort(t, sortfunc)
	return t
end


local SpellForm
local CooldownForm
local NewTimerForm


function NugRunningGUI.CreateNewTimerForm(self)
	local Form = AceGUI:Create("InlineGroup")
    Form:SetFullWidth(true)
    -- Form:SetHeight(0)
    Form:SetLayout("Flow")
	Form.opts = {}

	Form.ShowNewTimer = function(self, category)
		assert(category)
		local Frame = NugRunningGUI.frame
		local class = self.class

		Frame.rpane:Clear()
		if not SpellForm then
			SpellForm = NugRunningGUI:CreateSpellForm()
		end
		local opts = {}
		if class == "GLOBAL" then opts.global = true end
		NugRunningGUI:FillForm(SpellForm, class, category, nil, opts, true)
		Frame.rpane:AddChild(SpellForm)
	end

	local newspell = AceGUI:Create("Button")
	newspell:SetText("New Spell")
	newspell:SetFullWidth(true)
	newspell:SetCallback("OnClick", function(self, event)
		self.parent:ShowNewTimer("spells")
	end)
	Form:AddChild(newspell)

	local newcooldown = AceGUI:Create("Button")
	newcooldown:SetText("New Cooldown")
	newcooldown:SetFullWidth(true)
	newcooldown:SetCallback("OnClick", function(self, event)
		self.parent:ShowNewTimer("cooldowns")
	end)
	Form:AddChild(newcooldown)

	local newcast = AceGUI:Create("Button")
	newcast:SetText("New Cast")
	newcast:SetFullWidth(true)
	newcast:SetCallback("OnClick", function(self, event)
		self.parent:ShowNewTimer("casts")
	end)
	Form:AddChild(newcast)

	return Form
end





function NugRunningGUI.CreateCommonForm(self)
	local Form = AceGUI:Create("ScrollFrame")
    Form:SetFullWidth(true)
    -- Form:SetHeight(0)
    Form:SetLayout("Flow")
	Form.opts = {}
	Form.controls = {}




	local save = AceGUI:Create("Button")
	save:SetText("Save")
	save:SetRelativeWidth(0.5)
	save:SetCallback("OnClick", function(self, event)
		local p = self.parent
		local class = p.class
		local category = p.category
		local spellID = p.id
		local opts = p.opts

		if not spellID then -- make new timer
			spellID = tonumber(self.parent.controls.spellID:GetText())
			if not spellID then
				--invalid spell id
				return
			end

			if not opts.name then
				opts.name = GetSpellInfo(spellID)
			end
			if category == "spells" and not opts.duration then
				opts.duration = 3
			end
			opts.spellID = nil
		end

		if opts.ghost == false then opts.ghost = nil end
		if opts.singleTarget == false then opts.singleTarget = nil end
		if opts.multiTarget == false then opts.multiTarget = nil end
		if opts.scale and opts.scale >= 1 then opts.scale = nil end
		if opts.shine == false then opts.shine = nil end
		if opts.shinerefresh == false then opts.shinerefresh = nil end
		if opts.nameplates == false then opts.nameplates = nil end
		if opts.affiliation == COMBATLOG_OBJECT_AFFILIATION_MINE then opts.affiliation = nil end
		-- PRESAVE = p.opts
		local delta = CopyTable(opts)


		if NugRunningConfig[category][spellID] then
			NugRunning.RemoveDefaults(delta, NugRunningConfig[category][spellID])
			NugRunningConfigMerged[category][spellID] = CopyTable(NugRunningConfig[category][spellID])
			NugRunning.MergeTable(NugRunningConfigMerged[category][spellID], delta)
		else
			NugRunningConfigMerged[category][spellID] = delta
		end

		NugRunningConfigCustom[class] = NugRunningConfigCustom[class] or {}
		NugRunningConfigCustom[class][category] = NugRunningConfigCustom[class][category] or {}
		if not next(delta) then delta = nil end
		NugRunningConfigCustom[class][category][spellID] = delta

		NugRunningGUI.frame.tree:UpdateSpellTree()
		NugRunningGUI.frame.tree:SelectByPath(class, category, spellID)
		-- POSTSAVE = delta
	end)
	Form:AddChild(save)

	local delete = AceGUI:Create("Button")
	delete:SetText("Delete")
	save:SetRelativeWidth(0.5)
	delete:SetCallback("OnClick", function(self, event)
		local p = self.parent
		local class = p.class
		local category = p.category
		local spellID = p.id
		-- local opts = p.opts

		NugRunningConfigCustom[class][category][spellID] = nil
		NugRunningConfigMerged[category][spellID] = NugRunningConfig[category][spellID]

		NugRunningGUI.frame.tree:UpdateSpellTree()
		NugRunningGUI.frame.tree:SelectByPath(class, category, spellID)
	end)
	Form.controls.delete = delete
	Form:AddChild(delete)

	local spellID = AceGUI:Create("EditBox")
	spellID:SetLabel("Spell ID")
	spellID:SetDisabled(true)
	spellID:SetRelativeWidth(0.2)
	spellID:SetCallback("OnEnterPressed", function(self, event, value)
		self.parent.opts["spellID"] = value
	end)
	-- spellID:SetHeight(32)
	-- spellID.alignoffset = 30
	Form.controls.spellID = spellID
	Form:AddChild(spellID)

	local disabled = AceGUI:Create("CheckBox")
	disabled:SetLabel("Disabled")
	disabled:SetRelativeWidth(0.4)
	disabled:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["disabled"] = value
	end)
	-- disabled.alignoffset = 10
	-- disabled:SetHeight(36)
	Form.controls.disabled = disabled
	Form:AddChild(disabled)

	local short = AceGUI:Create("EditBox")
	short:SetLabel("Short Name")
	-- short:SetFullWidth(true)
	short:SetRelativeWidth(0.29)
	short:SetCallback("OnEnterPressed", function(self, event, value)
		self.parent.opts["short"] = value
	end)
	-- short.alignoffset = 60
	-- short:SetHeight(32)
	Form.controls.short = short
	Form:AddChild(short)

	local name = AceGUI:Create("EditBox")
	name:SetLabel("Name")
	-- name:SetFullWidth(true)
	name:SetRelativeWidth(0.5)
	name:SetCallback("OnEnterPressed", function(self, event, value)
		self.parent.opts["name"] = value
	end)
	-- name:SetHeight(32)
	Form.controls.name = name
	Form:AddChild(name)

	local duration = AceGUI:Create("EditBox")
	duration:SetLabel("Duration")
	duration:SetDisabled(true)
	duration:SetRelativeWidth(0.19)
	duration:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v and v > 0 then
			self.parent.opts["duration"] = v
		end
	end)
	Form.controls.duration = duration
	Form:AddChild(duration)

	local fixedlen = AceGUI:Create("EditBox")
	fixedlen:SetLabel("|cff00ff00Fixed Duration|r")
	fixedlen:SetRelativeWidth(0.2)
	fixedlen:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v and v > 0 then
			self.parent.opts["fixedlen"] = v
		else
			self.parent.opts["fixedlen"] = nil
			self:SetText("")
		end
	end)
	Form.controls.fixedlen = fixedlen
	Form:AddChild(fixedlen)


	local prio = AceGUI:Create("EditBox")
	prio:SetLabel("|cff55ff55Priority|r")
	-- prio:SetFullWidth(true)
	prio:SetRelativeWidth(0.15)
	prio:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v then
			self.parent.opts["priority"] = v
		end
	end)
	-- prio:SetHeight(32)
	Form.controls.priority = prio
	Form:AddChild(prio)

	local group = AceGUI:Create("Dropdown")
	group:SetLabel("Group")
	group:SetList({
		default = "Default",
		buffs = "Buffs",
		procs = "Procs"
	}, { "default", "buffs", "procs"})
	group:SetRelativeWidth(0.30)
	group:SetCallback("OnValueChanged", function(self, event, value)
		if value == "default" then value = nil end
		self.parent.opts["group"] = value
	end)
	-- group:SetHeight(32)
	Form.controls.group = group
	Form:AddChild(group)


	local scale = AceGUI:Create("Slider")
	scale:SetLabel("Scale")
	scale:SetSliderValues(0.3, 1, 0.05)
	scale:SetRelativeWidth(0.30)
	scale:SetCallback("OnValueChanged", function(self, event, value)
		local v = tonumber(value)
		if v and v >= 0.3 and v <= 1 then
			self.parent.opts["scale"] = v
		else
			self.parent.opts["scale"] = 1
			self:SetText(self.parent.opts.scale or "1")
		end
	end)
	Form.controls.scale = scale
	Form:AddChild(scale)

	local scale_until = AceGUI:Create("EditBox")
	scale_until:SetLabel("Minimize Until")
	scale_until:SetRelativeWidth(0.22)
	scale_until:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v then
			self.parent.opts["scale_until"] = v
		else
			self.parent.opts["scale_until"] = nil
			self:SetText("")
		end
	end)
	Form.controls.scale_until = scale_until
	Form:AddChild(scale_until)




	SHORTLABEL = short

	local color = AceGUI:Create("ColorPicker")
	color:SetLabel("Color")
	color:SetRelativeWidth(0.20)
	color:SetHasAlpha(false)
	color:SetCallback("OnValueConfirmed", function(self, event, r,g,b,a)
		self.parent.opts["color"] = {r,g,b}
	end)
	Form.controls.color = color
	Form:AddChild(color)

	local color2 = AceGUI:Create("ColorPicker")
	color2:SetLabel("Color2")
	color2:SetRelativeWidth(0.20)
	color2:SetHasAlpha(false)
	color2:SetCallback("OnValueConfirmed", function(self, event, r,g,b,a)
		self.parent.opts["color2"] = {r,g,b}
	end)
	Form.controls.color2 = color2
	Form:AddChild(color2)

	local c2r = AceGUI:Create("Button")
	c2r:SetText("X")
	c2r:SetRelativeWidth(0.1)
	c2r:SetCallback("OnClick", function(self, event)
		self.parent.opts["color2"] = nil
		self.parent.controls.color2:SetColor(0,0,0)
	end)
	Form.controls.c2r = c2r
	Form:AddChild(c2r)

	local arrow = AceGUI:Create("ColorPicker")
	arrow:SetLabel("Highlight")
	arrow:SetRelativeWidth(0.20)
	arrow:SetHasAlpha(false)
	arrow:SetCallback("OnValueConfirmed", function(self, event, r,g,b,a)
		self.parent.opts["arrow"] = {r,g,b}
	end)
	Form.controls.arrow = arrow
	Form:AddChild(arrow)

	local ar = AceGUI:Create("Button")
	ar:SetText("X")
	ar:SetRelativeWidth(0.1)
	ar:SetCallback("OnClick", function(self, event)
		self.parent.opts["arrow"] = nil
		self.parent.controls.arrow:SetColor(0,0,0)
	end)
	Form.controls.ar = ar
	Form:AddChild(ar)

	local ghost = AceGUI:Create("CheckBox")
	ghost:SetLabel("Ghost")
	ghost:SetRelativeWidth(0.32)
	ghost:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["ghost"] = value
	end)
	Form.controls.ghost = ghost
	Form:AddChild(ghost)

	local shine = AceGUI:Create("CheckBox")
	shine:SetLabel("Shine")
	shine:SetRelativeWidth(0.32)
	shine:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["shine"] = value
	end)
	Form.controls.shine = shine
	Form:AddChild(shine)

	local shinerefresh = AceGUI:Create("CheckBox")
	shinerefresh:SetLabel("On Refresh")
	shinerefresh:SetRelativeWidth(0.32)
	shinerefresh:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["shinerefresh"] = value
	end)
	Form.controls.shinerefresh = shinerefresh
	Form:AddChild(shinerefresh)




	local maxtimers = AceGUI:Create("EditBox")
	maxtimers:SetLabel("Max Timers")
	maxtimers:SetRelativeWidth(0.25)
	maxtimers:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v and v > 0 then
			self.parent.opts["maxtimers"] = value
		else
			self.parent.opts["maxtimers"] = nil
			self:SetText("")
		end
	end)
	Form.controls.maxtimers = maxtimers
	Form:AddChild(maxtimers)


	local singleTarget = AceGUI:Create("CheckBox")
	singleTarget:SetLabel("Single-Target")
	singleTarget:SetRelativeWidth(0.3)
	singleTarget:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["singleTarget"] = value
		if value then
			self.parent.controls.multiTarget:SetValue(false)
		end
	end)
	Form.controls.singleTarget = singleTarget
	Form:AddChild(singleTarget)

	local multiTarget = AceGUI:Create("CheckBox")
	multiTarget:SetLabel("Multi-Target")
	multiTarget:SetRelativeWidth(0.3)
	multiTarget:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["multiTarget"] = value
		if value then
			self.parent.controls.singleTarget:SetValue(false)
		end
	end)
	Form.controls.multiTarget = multiTarget
	Form:AddChild(multiTarget)


	local affiliation = AceGUI:Create("Dropdown")
	affiliation:SetLabel("Affiliation")
	affiliation:SetList({
		[COMBATLOG_OBJECT_AFFILIATION_MINE] = "Player",
		[COMBATLOG_OBJECT_AFFILIATION_PARTY_OR_RAID] = "Raid",
		[COMBATLOG_OBJECT_AFFILIATION_OUTSIDER] = "Any"
	}, { 1, 6, 8})
	affiliation:SetRelativeWidth(0.40)
	affiliation:SetCallback("OnValueChanged", function(self, event, value)
		if value == "player" then value = nil end
		self.parent.opts["affiliation"] = value
	end)
	Form.controls.affiliation = affiliation
	Form:AddChild(affiliation)

	local nameplates = AceGUI:Create("CheckBox")
	nameplates:SetLabel("Show on Nameplates")
	nameplates:SetRelativeWidth(0.5)
	nameplates:SetCallback("OnValueChanged", function(self, event, value)
		self.parent.opts["nameplates"] = value
	end)
	Form.controls.nameplates = nameplates
	Form:AddChild(nameplates)


	local overlay_start = AceGUI:Create("EditBox")
	overlay_start:SetLabel("Overlay Start")
	overlay_start:SetRelativeWidth(0.25)
	overlay_start:SetCallback("OnEnterPressed", function(self, event, value)
		local v
		if value == "tick" or value == "tickend" or value ==  "end" or value == "gcd" then
			v = value
		else
			v = tonumber(value)
			if v <= 0 then v = nil end
		end
		if v then
			if not self.parent.opts.overlay then
				self.parent.opts.overlay = {v, nil, 0.3, nil}
			else
				self.parent.opts.overlay[1] = v
			end
		else
			self.parent.opts["overlay"] = nil
			self:SetText("")
			self.parent.controls.overlay_end:SetText("")
		end
	end)
	Form.controls.overlay_start = overlay_start
	Form:AddChild(overlay_start)

	local overlay_end = AceGUI:Create("EditBox")
	overlay_end:SetLabel("Overlay End")
	overlay_end:SetRelativeWidth(0.25)
	overlay_end:SetCallback("OnEnterPressed", function(self, event, value)
		local v
		if value == "tick" or value == "tickend" or value ==  "end" or value == "gcd" then
			v = value
		else
			v = tonumber(value)
			if v <= 0 then v = nil end
		end
		if v then
			if not self.parent.opts.overlay then
				self.parent.opts.overlay = {nil, v, 0.3, nil}
			else
				self.parent.opts.overlay[2] = v
			end
		else
			self.parent.opts["overlay"] = nil
			self:SetText("")
			self.parent.controls.overlay_end:SetText("")
		end
	end)
	Form.controls.overlay_end = overlay_end
	Form:AddChild(overlay_end)

	local overlay_haste = AceGUI:Create("CheckBox")
	overlay_haste:SetLabel("Haste Reduced")
	overlay_haste:SetRelativeWidth(0.4)
	overlay_haste:SetCallback("OnValueChanged", function(self, event, value)
		if not self.parent.opts.overlay then
			self.parent.opts.overlay = {nil, nil, 0.3, v}
		else
			self.parent.opts.overlay[4] = v
		end
	end)
	Form.controls.overlay_haste = overlay_haste
	Form:AddChild(overlay_haste)

	local tick = AceGUI:Create("EditBox")
	tick:SetLabel("Tick")
	tick:SetRelativeWidth(0.15)
	tick:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v then
			self.parent.opts["tick"] = v
			self.parent.opts["recast_mark"] = nil
			self.parent.controls.recast_mark:SetText("")
		else
			self.parent.opts["tick"] = nil
			self:SetText("")
		end
	end)
	Form.controls.tick = tick
	Form:AddChild(tick)

	local recast_mark = AceGUI:Create("EditBox")
	recast_mark:SetLabel("Recast Mark")
	recast_mark:SetRelativeWidth(0.15)
	recast_mark:SetCallback("OnEnterPressed", function(self, event, value)
		local v = tonumber(value)
		if v and v > 0 then
			self.parent.opts["recast_mark"] = v
			self.parent.opts["tick"] = nil
			self.parent.controls.tick:SetText("")
		else
			self.parent.opts["recast_mark"] = nil
			self:SetText("")
		end
	end)
	Form.controls.recast_mark = recast_mark
	Form:AddChild(recast_mark)



    -- Frame:AddChild(Form)
    -- Frame.top = Form
	return Form
end

function NugRunningGUI.CreateSpellForm(self)
	local topgroup = NugRunningGUI:CreateCommonForm()

	return topgroup
end

function NugRunningGUI.FillForm(self, Form, class, category, id, opts, isEmptyForm)
	Form.opts = opts
	Form.class = class
	Form.category = category
	Form.id = id
	local controls = Form.controls
	controls.spellID:SetText(id or "")
	controls.spellID:SetDisabled(not isEmptyForm)
	controls.disabled:SetValue(false)
	controls.disabled:SetDisabled(isEmptyForm)

	controls.name:SetText(opts.name)
	controls.priority:SetText(opts.priority)
	controls.group:SetValue(opts.group or "default")
	controls.short:SetText(opts.short)
	controls.duration:SetText(opts.duration)
	controls.scale:SetValue(opts.scale or 1)
	controls.scale_until:SetText(opts.scale_until)
	controls.shine:SetValue(opts.shine)
	controls.shinerefresh:SetValue(opts.shinerefresh)

	if opts.ghost then
		controls.ghost:SetValue(true)
	else
		controls.ghost:SetValue(false)
	end
	controls.maxtimers:SetText(opts.maxtimers)
	controls.singleTarget:SetValue(opts.singleTarget)
	controls.multiTarget:SetValue(opts.multiTarget)

	controls.color:SetColor(unpack(opts.color or {0.8, 0.1, 0.7} ))
	-- print(unpack(opts.color2))
	controls.color2:SetColor(unpack(opts.color2 or {0,0,0} ))
	controls.arrow:SetColor(unpack(opts.arrow or {0,0,0} ))

	controls.affiliation:SetValue(opts.affiliation or COMBATLOG_OBJECT_AFFILIATION_MINE)
	controls.nameplates:SetValue(opts.namaplates)

	controls.tick:SetText(opts.tick)
	controls.recast_mark:SetText(opts.recast_mark)
	controls.fixedlen:SetText(opts.fixedlen)

	if opts.overlay then
		controls.overlay_start:SetText(opts.overlay[1])
		controls.overlay_end:SetText(opts.overlay[2])
		controls.overlay_haste:SetValue(opts.overlay[4])
	else
		controls.overlay_start:SetText("")
		controls.overlay_end:SetText("")
		controls.overlay_haste:SetValue(false)
	end


	if id and not NugRunningConfig[category][id] then
		controls.delete:SetDisabled(false)
		controls.delete:SetText("Delete")
	elseif NugRunningConfigCustom[class] and  NugRunningConfigCustom[class][category] and NugRunningConfigCustom[class][category][id] then
		controls.delete:SetDisabled(false)
		controls.delete:SetText("Restore")
	else
		controls.delete:SetDisabled(true)
		controls.delete:SetText("Delete")
	end


	if category == "spells" then
		controls.duration:SetDisabled(false)
		controls.maxtimers:SetDisabled(false)
		controls.singleTarget:SetDisabled(false)
		controls.multiTarget:SetDisabled(false)
		controls.affiliation:SetDisabled(false)
		controls.nameplates:SetDisabled(false)
	else
		controls.duration:SetDisabled(true)
		controls.maxtimers:SetDisabled(true)
		controls.singleTarget:SetDisabled(true)
		controls.multiTarget:SetDisabled(true)
		controls.affiliation:SetDisabled(true)
		controls.nameplates:SetDisabled(true)
	end

end



function NugRunningGUI.Create( self )
    -- Create a container frame
    -- local Frame = AceGUI:Create("Frame")
    -- Frame:SetTitle("NugRunningGUI")
    -- Frame:SetWidth(500)
    -- Frame:SetHeight(440)
    -- Frame:EnableResize(false)
    -- -- f:SetStatusText("Status Bar")
	-- -- Frame:SetParent(InterfaceOptionsFramePanelContainer)
    -- Frame:SetLayout("Flow")
	-- Frame:Hide()

	local Frame = AceGUI:Create("BlizOptionsGroup")
	Frame:SetName("NugRunning")
	Frame:SetTitle("NugRunning Options")
	Frame:SetLayout("Fill")
	-- Frame:SetHeight(500)
	-- Frame:SetWidth(700)
	NRO = Frame
	-- Frame:Show()



	-- local gr = AceGUI:Create("InlineGroup")
	-- gr:SetLayout("Fill")
	-- -- gr:SetWidth(600)
	-- -- gr:SetHeight(600)
	-- Frame:AddChild(gr)
	--
	-- local setcreate = AceGUI:Create("Button")
    -- setcreate:SetText("Save")
    -- -- setcreate:SetWidth(100)
	-- gr:AddChild(setcreate)
	-- if true then
		-- return Frame
	-- end


	-- local Frame = CreateFrame("Frame", "NugRunningOptions", UIParent) -- InterfaceOptionsFramePanelContainer)
	-- -- Frame:Hide()
	-- Frame.name = "NugRunningOptions"
	-- Frame.children = {}
	-- Frame:SetWidth(400)
	-- Frame:SetHeight(400)
	-- Frame:SetPoint("CENTER", UIParent, "CENTER",0,0)
	-- Frame.AddChild = function(self, child)
	-- 	table.insert(self.children, child)
	-- 	child:SetParent(self)
	-- end
	-- InterfaceOptions_AddCategory(Frame)


    -- local topgroup = AceGUI:Create("InlineGroup")
    -- topgroup:SetFullWidth(true)
    -- -- topgroup:SetHeight(0)
    -- topgroup:SetLayout("Flow")
    -- Frame:AddChild(topgroup)
    -- Frame.top = topgroup
	--
    -- local setname = AceGUI:Create("EditBox")
    -- setname:SetWidth(240)
    -- setname:SetText("NewSet1")F
    -- setname:DisableButton(true)
    -- topgroup:AddChild(setname)
    -- topgroup.label = setname
	--
    -- local setcreate = AceGUI:Create("Button")
    -- setcreate:SetText("Save")
    -- setcreate:SetWidth(100)
    -- setcreate:SetCallback("OnClick", function(self) NugRunningGUI:SaveSet() end)
    -- setcreate:SetCallback("OnEnter", function() Frame:SetStatusText("Create new/overwrite existing set") end)
    -- setcreate:SetCallback("OnLeave", function() Frame:SetStatusText("") end)
    -- topgroup:AddChild(setcreate)
	--
    -- local btn4 = AceGUI:Create("Button")
    -- btn4:SetWidth(100)
    -- btn4:SetText("Delete")
    -- btn4:SetCallback("OnClick", function() NugRunningGUI:DeleteSet() end)
    -- topgroup:AddChild(btn4)
    -- -- Frame.rpane:AddChild(btn4)
    -- -- Frame.rpane.deletebtn = btn4



    local treegroup = AceGUI:Create("TreeGroup") -- "InlineGroup" is also good
	-- treegroup:SetParent(InterfaceOptionsFramePanelContainer)
	-- treegroup.name = "NugRunningOptions"
    -- treegroup:SetFullWidth(true)
    -- treegroup:SetTreeWidth(200, false)
    -- treegroup:SetLayout("Flow")
    treegroup:SetFullHeight(true) -- probably?
	treegroup:SetFullWidth(true) -- probably?
    treegroup:SetCallback("OnGroupSelected", function(self, event, group)
		local path = {}
		for match in string.gmatch(group, '([^\001]+)') do
			table.insert(path, match)
		end

		local class, category, spellID = unpack(path)
		if not spellID or not category then
			Frame.rpane:Clear()
			if not NewTimerForm then
				NewTimerForm = NugRunningGUI:CreateNewTimerForm()
			end
			NewTimerForm.class = class
			Frame.rpane:AddChild(NewTimerForm)
			return
		end

		spellID = tonumber(spellID)
		local opts
		if not NugRunningConfigCustom[class] or not NugRunningConfigCustom[class][category] or not NugRunningConfigCustom[class][category][spellID] then
			opts = {}
		else
			opts = CopyTable(NugRunningConfigCustom[class][category][spellID])
		end
		NugRunning.SetupDefaults(opts, NugRunningConfig[category][spellID])

		-- if category == "spells" then
		Frame.rpane:Clear()
		if not SpellForm then
			SpellForm = NugRunningGUI:CreateSpellForm()
		end
		NugRunningGUI:FillForm(SpellForm, class, category, spellID, opts)
		Frame.rpane:AddChild(SpellForm)

		-- end
	end)

	Frame.rpane = treegroup
	Frame.tree = treegroup

	treegroup.UpdateSpellTree = function(self)
		local lclass, class = UnitClass("player")
		local classIcon = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
		local classCoords = CLASS_ICON_TCOORDS[class]

		local t = {
			{
				value = "GLOBAL",
				text = "Global",
				icon = "Interface\\Icons\\spell_holy_resurrection",
				children = {
					{
						value = "spells",
						text = "Spells",
						icon = "Interface\\Icons\\spell_shadow_manaburn",
						children = NugRunningGUI:GenerateCategoryTree(true, "spells")
					},
					-- {
					-- 	value = "cooldowns",
					-- 	text = "Cooldowns",
					-- 	icon = "Interface\\Icons\\spell_nature_astralrecal",
					-- 	children = NugRunningGUI:GenerateCategoryTree(true, "cooldowns")
					-- },
					-- {
					-- 	value = "casts",
					-- 	text = "Casts",
					-- 	icon = "Interface\\Icons\\spell_deathvortex",
					-- 	children = NugRunningGUI:GenerateCategoryTree(true, "casts")
					-- },
				},
			},
			{
				value = class,
				text = lclass,
				icon = classIcon,
				iconCoords = classCoords,
				children = {
					{
						value = "spells",
						text = "Spells",
						icon = "Interface\\Icons\\spell_shadow_manaburn",
						children = NugRunningGUI:GenerateCategoryTree(false,"spells")
					},
					{
						value = "cooldowns",
						text = "Cooldowns",
						icon = "Interface\\Icons\\spell_nature_astralrecal",
						children = NugRunningGUI:GenerateCategoryTree(false,"cooldowns")
					},
					{
						value = "casts",
						text = "Casts",
						icon = "Interface\\Icons\\spell_deathvortex",
						children = NugRunningGUI:GenerateCategoryTree(false,"casts")
					},
					-- {
					-- 	value = "event_timers",
					-- 	text = "Events",
					-- 	icon = "ability_deathwing_sealarmorbreachtga",
					-- 	children = NugRunningGUI:GenerateCategoryTree("casts")
					-- }
				}
			},
		}
		self:SetTree(t)
		return t
	end


	local t = treegroup:UpdateSpellTree()

	Frame:AddChild(treegroup)



	local categories = {"spells", "cooldowns", "casts"}
	for i,group in ipairs(t) do -- expand all groups
		if group.value ~= "GLOBAL" then
			treegroup.localstatus.groups[group.value] = true
			for _, cat in ipairs(categories) do
				treegroup.localstatus.groups[group.value.."\001"..cat] = true
			end
		end
	end
	-- TREEG = treegroup


	Frame.rpane.Clear = function(self)
		for i, child in ipairs(self.children) do
			child:SetParent(UIParent)
			child.frame:Hide()
		end
		table.wipe(self.children)
	end



	-- local commonForm = NugRunningGUI:CreateCommonForm()
	-- Frame.rpane:AddChild(commonForm)
	local _, class = UnitClass("player")
	Frame.tree:SelectByPath(class)



    -- Frame:Hide()

    return Frame
end

do
	NugRunningGUI.frame = NugRunningGUI:Create()
	InterfaceOptions_AddCategory(NugRunningGUI.frame.frame);
end
