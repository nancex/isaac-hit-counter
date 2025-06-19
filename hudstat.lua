local dogmaEnded = false

local function didPlayerDualityCountJustChange(player)
	local data = player:GetData()
	if data.didDualityCountJustChange then
		return true
	end
	return false
end

local function didPlayerCharacterJustChange(player)
	local data = player:GetData()
	if data.playerTypeJustChanged then
		return true
	end
	return false
end

local function canRunUnlockAchievements() -- by Xalum
	local machine = Isaac.Spawn(6, 11, 0, Vector.Zero, Vector.Zero, nil)
	local achievementsEnabled = machine:Exists()
	machine:Remove()

	return achievementsEnabled
end

local function textBias(frame)
	if frame > 14 then
		return 0
	end
	frame = frame - 14
	return -(15.1 / (13 * 13)) * frame * frame
end

local function isBeastRoom(room)                                                             -- same as how the vanilla game detects it
	return room and room:GetType() == RoomType.ROOM_DUNGEON and room:GetRoomConfigStage() == 35 -- home
end

local function isDogmaDefeated()
	-- This is super lame, but the only way to avoid drawing over the death animation (dogma flash) is by considering dogma "dead" after 80 frames of his death animation have played.
	if dogmaEnded then return true end
	local isDogma = Game():GetLevel():GetAbsoluteStage() == LevelStage.STAGE8 and
		Game():GetRoom():IsCurrentRoomLastBoss()
	if isDogma then
		for _, v in pairs(Isaac.GetRoomEntities()) do
			if v:IsBoss() and v:GetSprite():GetAnimation() == "Death" and v:GetSprite():GetFrame() > 80 then
				dogmaEnded = true
				return true
			end
		end
	end
	return false
end

--------------------------------------------------------------------------------------

local hudstat = {}

function hudstat:init(mod)
	self.mod = mod

	self.hudSprite = Sprite()
	self.hudSprite.Color = Color(1, 1, 1, 0.5)

	self.font = Font()
	self.font:Load("font/luaminioutlined.fnt")

	self.renderString = "???"

	self.extraFrames = 250
	self.fontalpha = 0
	self.iconPopupFrame = 20

	mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
		local data = player:GetData()
		local currentDualityCount = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_DUALITY)
		if not data.lastDualityCount then
			data.lastDualityCount = currentDualityCount
		end
		data.didDualityCountJustChange = false
		if data.lastDualityCount ~= currentDualityCount then
			data.didDualityCountJustChange = true
		end
		data.lastDualityCount = currentDualityCount
	end)

	mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
		local data = player:GetData()
		local playerType = player:GetPlayerType()
		if not data.lastPlayerType then
			data.lastPlayerType = playerType
		end
		data.playerTypeJustChanged = false
		if data.lastPlayerType ~= playerType then
			data.playerTypeJustChanged = true
		end
		data.lastPlayerType = playerType
	end)

	local function onRender(_, shaderName)
		if hudstat:__shouldDeHook() then return end
		local isShader = shaderName == "UI_DrawHitCounter_DummyShader"

		if not (Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled) and not isShader then return end -- no render when unpaused
		if (Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled) and isShader then return end   -- no shader when paused

		if shaderName ~= nil and not isShader then return end                                        -- final failsafe

		hudstat:__updateCheck()

		--account for screenshake offset
		local textCoords = self.coords + Game().ScreenShakeOffset

		self.font:DrawString(self.renderString, textCoords.X + 16, textCoords.Y + 1, KColor(1, 1, 1, 0.5), 0, true)

		--icon popup
		local iconScale = 1
		if self.iconPopupFrame < 7 then
			iconScale = 1 + (self.iconPopupFrame / 8) * 0.2
			self.iconPopupFrame = self.iconPopupFrame + 1
		elseif self.iconPopupFrame < 13 then
			iconScale = 1 + 0.2 - (self.iconPopupFrame - 8) / 8 * 0.2
			self.iconPopupFrame = self.iconPopupFrame + 1
		end
		if self.hudSprite:IsLoaded() then
			self.hudSprite.Scale = Vector(iconScale, iconScale)
			self.hudSprite:Render(self.coords + Vector(8, 8))
		end

		--text differential popup
		if self.fontalpha > 0 then
			if self.diffCurFrame > 14 + self.extraFrames then
				self.fontalpha = self.fontalpha - 0.01
			end

			local bias = textBias(self.diffCurFrame)
			if self.isDiffPositive then
				self.font:DrawString(self.diffString, textCoords.X + 46 + bias, textCoords.Y + 1,
					KColor(0, 1, 0, self.fontalpha), 0, true)
			else
				self.font:DrawString(self.diffString, textCoords.X + 46 + bias, textCoords.Y + 1,
					KColor(1, 0, 0, self.fontalpha), 0, true)
			end

			self.diffCurFrame = self.diffCurFrame + 1
		end
	end

	mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, onRender)
	mod:AddCallback(ModCallbacks.MC_POST_RENDER, onRender)

	mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
		dogmaEnded = false
		self:__updatePosition()
	end)
	mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	end)

	--Custom Shader Fix by AgentCucco
	mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
		if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
			Isaac.ExecuteCommand("reloadshaders")
		end
	end)
end

function hudstat:setIconFrame(anim, frame, popup)
	hudstat.hudSprite:SetFrame(anim, frame)
	if popup then
		self.iconPopupFrame = 1
	end
end

function hudstat:setRenderString(str)
	self.renderString = str
end

function hudstat:setDiff(positive, diff, extraFrames)
	if positive then
		self.isDiffPositive = true
	else
		self.isDiffPositive = false
	end
	self.diffString = tostring(diff)
	self.diffCurFrame = 1
	self.extraFrames = extraFrames or self.extraFrames
	self.fontalpha = 0.5
end

--------------------------------------------------------------------------------------

function hudstat:__shouldDeHook()
	-- Hide the icon IF:
	local reqs = {
		not Options.FoundHUD,
		not Game():GetHUD():IsVisible(),
		isDogmaDefeated(),
		isBeastRoom(Game():GetRoom()),
		Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD),
	}

	return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5]
end

function hudstat:__updatePosition()
	local TrueCoopShift = false
	local BombShift = false
	local PoopShift = false
	local RedHeartShift = false
	local SoulHeartShift = false
	local DualityShift = false

	local ShiftCount = 0

	if REPENTANCE_PLUS then
		self.coords = Vector(0, 170)
	else
		self.coords = Vector(0, 168)
	end

	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		local playerType = player:GetPlayerType()

		if player:GetBabySkin() == -1 then
			if i > 0 and player.Parent == nil and playerType == player:GetMainTwin():GetPlayerType() and not TrueCoopShift then
				TrueCoopShift = true
			end

			if playerType ~= PlayerType.PLAYER_BLUEBABY_B and not BombShift then -- Shift Stats because of Bomb Counter
				BombShift = true
			end
		end
		if playerType == PlayerType.PLAYER_BLUEBABY_B and not PoopShift then -- Shift Stats because of Poop Spell Counter
			PoopShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY_B and not RedHeartShift then -- Shifts Stats because of Red Heart Counter
			RedHeartShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY and not SoulHeartShift then -- Shifts Stats because of Soul Heart Counter
			SoulHeartShift = true
		end

		if player:HasCollectible(CollectibleType.COLLECTIBLE_DUALITY) and not DualityShift then -- Shifts Stats because of Duality
			DualityShift = true
		end
	end

	if BombShift then
		ShiftCount = ShiftCount + 1
	end
	if PoopShift then
		ShiftCount = ShiftCount + 1
	end
	if RedHeartShift then
		ShiftCount = ShiftCount + 1
	end
	if SoulHeartShift then
		ShiftCount = ShiftCount + 1
	end
	ShiftCount = ShiftCount - 1 -- There will always be 1 ShiftCount due to bombs and poop, so its safe to do this
	if ShiftCount > 0 then
		self.coords = self.coords + Vector(0, (11 * ShiftCount) - 2)
	end

	--For some reason whether or not Jacob&Esau are 1st player or another player matters, so I have to check specifically if Jacob is player 1 here
	if Isaac.GetPlayer(0):GetPlayerType() == PlayerType.PLAYER_JACOB then
		self.coords = self.coords + Vector(0, 30)
	elseif TrueCoopShift then
		self.coords = self.coords + Vector(0, 16)
		if DualityShift then
			self.coords = self.coords + Vector(0, -2) -- I hate this
		end
	end
	if DualityShift then
		self.coords = self.coords + Vector(0, -12)
	end

	--Checks if Hard Mode and Seeded/Challenge/Daily; Seeded/Challenge have no achievements logo, and Daily Challenge has destination logo.
	if Game().Difficulty == Difficulty.DIFFICULTY_HARD or Game():IsGreedMode() or not canRunUnlockAchievements() then
		self.coords = self.coords + Vector(0, 16)
	end

	self.coords = self.coords + (Options.HUDOffset * Vector(20, 12))

	self:__forCompat()
end

function hudstat:__forCompat()
	if PlanetariumChance then
		self.coords = self.coords + Vector(0, 12)
	end
end

function hudstat:__updateCheck()
	local updatePos = false

	local activePlayers = Game():GetNumPlayers()

	for p = 1, activePlayers do
		local player = Isaac.GetPlayer(p - 1)
		if player.FrameCount == 0 or didPlayerCharacterJustChange(player) or didPlayerDualityCountJustChange(player) then
			updatePos = true
		end
	end

	if self.numplayers ~= activePlayers then
		updatePos = true
		self.numplayers = activePlayers
	end

	if self.hudoffset ~= Options.HUDOffset then
		updatePos = true
		self.hudoffset = Options.HUDOffset
	end

	--Was a Victory Lap Completed, Runs completed on Normal Difficulty Will switch to HARD upon start of a Victory Lap
	if self.VictoryLap ~= Game():GetVictoryLap() then
		updatePos = true
		self.VictoryLap = Game():GetVictoryLap()
	end

	--Certain Seed Effects block achievements
	if self.NumSeedEffects ~= Game():GetSeeds():CountSeedEffects() then
		updatePos = true
		self.NumSeedEffects = Game():GetSeeds():CountSeedEffects()
	end

	if updatePos then
		self:__updatePosition()
	end
end

return hudstat
