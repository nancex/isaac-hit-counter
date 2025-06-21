HitCounter = RegisterMod("Hit Counter by nancex", 1)
local mod = HitCounter
local hudstat = require("hudstat")
local json = require("json")

local storageLoaded = false

local function isSelfDamage(damageFlags)
	local selfDamageFlags = {
		['IVBag'] = DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_INVINCIBLE | DamageFlag.DAMAGE_IV_BAG,
		['Confessional'] = DamageFlag.DAMAGE_RED_HEARTS,
		['DemonBeggar'] = DamageFlag.DAMAGE_RED_HEARTS,
		['BloodDonationMachine'] = DamageFlag.DAMAGE_RED_HEARTS,
		['HellGame'] = DamageFlag.DAMAGE_RED_HEARTS,
		['CurseRoom'] = DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_CURSED_DOOR,
		['MausoleumDoor'] = DamageFlag.DAMAGE_SPIKES | DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_INVINCIBLE |
			DamageFlag.DAMAGE_NO_MODIFIERS,
		['SacrificeRoom'] = DamageFlag.DAMAGE_SPIKES | DamageFlag.DAMAGE_NO_PENALTIES,
		['SpikedChest'] = DamageFlag.DAMAGE_CHEST | DamageFlag.DAMAGE_NO_PENALTIES,
		['BadTrip'] = DamageFlag.DAMAGE_NOKILL | DamageFlag.DAMAGE_INVINCIBLE | DamageFlag.DAMAGE_NO_PENALTIES
	}

	for _, flags in pairs(selfDamageFlags) do
		if damageFlags & flags == flags then
			return true
		end
	end
	return false
end

local function trueDeath()
	local player = Isaac.GetPlayer(0)
	if not player then return end

	local reviveItems = {
		CollectibleType.COLLECTIBLE_DEAD_CAT,
		CollectibleType.COLLECTIBLE_1UP,
		CollectibleType.COLLECTIBLE_ANKH,
		CollectibleType.COLLECTIBLE_INNER_CHILD,
		CollectibleType.COLLECTIBLE_GUPPYS_COLLAR,
		CollectibleType.COLLECTIBLE_LAZARUS_RAGS,
		CollectibleType.COLLECTIBLE_JUDAS_SHADOW,
		CollectibleType.COLLECTIBLE_BIRTHRIGHT, -- tainted lost
	}
	local reviveTrinkets = {
		TrinketType.TRINKET_MISSING_POSTER,
		TrinketType.TRINKET_MYSTERIOUS_PAPER,
		TrinketType.TRINKET_BROKEN_ANKH
	}
	local reviveCards = {
		Card.CARD_SOUL_LAZARUS
	}

	for _, itemID in ipairs(reviveItems) do
		if player:HasCollectible(itemID) then
			player:RemoveCollectible(itemID)
		end
	end

	for _, trinketID in ipairs(reviveTrinkets) do
		if player:HasTrinket(trinketID) then
			player:TryRemoveTrinket(trinketID)
		end
	end

	for _, cardID in ipairs(reviveCards) do
		if player:GetCard(0) == cardID or player:GetCard(1) == cardID then
			player:SetCard(0, Card.CARD_NULL)
			player:SetCard(1, Card.CARD_NULL)
		end
	end

	player:AddCollectible(CollectibleType.COLLECTIBLE_FATE)
	player:Kill()
end

local function deepMerge(target, source)
	for key, targetValue in pairs(target) do
		local sourceValue = source[key]
		if sourceValue ~= nil then
			if type(targetValue) == "table" and type(sourceValue) == "table" then
				deepMerge(targetValue, sourceValue)
			else
				target[key] = sourceValue
			end
		end
	end
end

local function loadStorage()
	local data = mod:LoadData()
	if data then
		local oldStorage = json.decode(data)
		if type(oldStorage) == "table" then
			deepMerge(mod.storage, oldStorage)
		end
	end
end

local function modConfigMenuInit()
	if ModConfigMenu == nil then
		return
	end

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.storage.settings.statBias.X
			end,
			Display = function()
				return "Stat HUD Position X: " .. mod.storage.settings.statBias.X
			end,
			OnChange = function(n)
				mod.storage.settings.statBias.X = n
				hudstat:setPosBias(3 * Vector(n, mod.storage.settings.statBias.Y))
			end,
			Info = {
				"Position of the HUD element on the X axis.",
				"",
			}
		}
	)

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.storage.settings.statBias.Y
			end,
			Display = function()
				return "Stat HUD Position Y: " .. mod.storage.settings.statBias.Y
			end,
			OnChange = function(n)
				mod.storage.settings.statBias.Y = n
				hudstat:setPosBias(3 * Vector(mod.storage.settings.statBias.X, n))
			end,
			Info = {
				"Position of the HUD element on the Y axis.",
				"",
			}
		}
	)

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return mod.storage.settings.hardcoreMode
			end,
			Display = function()
				return "Hardcore Mode: " .. (mod.storage.settings.hardcoreMode and "ON" or "OFF")
			end,
			OnChange = function(b)
				mod.storage.settings.hardcoreMode = b
				if mod.storage.settings.hardcoreMode then
					if mod.storage.settings.hcHitsMax <= mod.storage.hitsTaken then
						mod.storage.hitsTaken = mod.storage.settings.hcHitsMax - 1
					end
					hudstat:setRenderString(string.format(" %d", mod.storage.settings.hcHitsMax - mod.storage.hitsTaken))
				else
					hudstat:setRenderString(string.format(" %d", mod.storage.hitsTaken))
				end
				hudstat:setIconFrame("1", math.min(mod.storage.hitsTaken, 7), false)
			end,
			Info = {
				"You got limited hits.",
				"Run out of hits and you die.",
			}
		}
	)

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.storage.settings.hcHitsMax
			end,
			Display = function()
				return "Hardcore Max Hits: " .. mod.storage.settings.hcHitsMax
			end,
			OnChange = function(newHitsMax)
				if mod.storage.settings.hardcoreMode and not mod.storage.onceHit then
					mod.storage.settings.hcHitsMax = newHitsMax > 0 and newHitsMax or 1
					hudstat:setRenderString(string.format(" %d", newHitsMax))
				end
			end,
			Info = {
				"Max Hits till you die.",
				"Can't be changed after took hits.",
			}
		}
	)

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return mod.storage.settings.funnyEffects
			end,
			Display = function()
				return "Funny Effects When Killed: " .. (mod.storage.settings.funnyEffects and "ON" or "OFF")
			end,
			OnChange = function(b)
				mod.storage.settings.funnyEffects = b
			end,
			Info = {
				"Hardcore only.",
				"Mega bomb and metal pipe sound",
			}
		}
	)

	ModConfigMenu.AddSetting(
		"Hit Counter",
		nil,
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return mod.storage.settings.floorNoHitBonus
			end,
			Display = function()
				return "Floor No Hit Bonus: " .. (mod.storage.settings.floorNoHitBonus and "ON" or "OFF")
			end,
			OnChange = function(b)
				mod.storage.settings.floorNoHitBonus = b
			end,
			Info = {
				"Hardcore only.",
				"Increases your hit countdown by 1.",
			}
		}
	)
end

function mod:onEntityDamage(entity, amount, flags, source, countdown)
	if entity:ToPlayer() and not isSelfDamage(flags) then
		mod.storage.hitsTaken = mod.storage.hitsTaken + 1
		mod.storage.hitsTakenFloor = mod.storage.hitsTakenFloor + 1
		if not mod.storage.onceHit then mod.storage.onceHit = true end

		if self.storage.settings.hardcoreMode then
			local remainHits = self.storage.settings.hcHitsMax - self.storage.hitsTaken
			hudstat:setDiff(false, "-1", 60)
			hudstat:setRenderString(string.format(" %d", remainHits))

			if remainHits <= 0 then
				local player = Isaac.GetPlayer(0)

				trueDeath()
				self.playerKilled = true

				if self.storage.settings.funnyEffects then
					Game():BombExplosionEffects(player.Position, 300, TearFlags.TEAR_GIGA_BOMB, Color.Default, player, 1,
						true,
						false,
						DamageFlag.DAMAGE_EXPLOSION)
					SFXManager():Play(Isaac.GetSoundIdByName("MetalPipe"))
				end
			end
		else
			hudstat:setDiff(false, "+1", 60)
			hudstat:setRenderString(string.format(" %d", mod.storage.hitsTaken))
		end

		hudstat:setIconFrame("1", math.min(mod.storage.hitsTaken, 7), true)
	end
	return nil
end

function mod:onGameStarted(continued)
	if not storageLoaded then
		loadStorage()
		storageLoaded = true
	end

	self.storage.onceHit = false
	self.playerKilled = false

	local v = Vector(3 * mod.storage.settings.statBias.X, 3 * mod.storage.settings.statBias.Y)
	hudstat:setPosBias(v)

	if continued then
		if self.storage.settings.hardcoreMode then
			hudstat:setRenderString(string.format(" %d", self.storage.settings.hcHitsMax - self.storage.hitsTaken))
		else
			hudstat:setRenderString(string.format(" %d", self.storage.hitsTaken))
		end
		hudstat:setIconFrame("1", math.min(self.storage.hitsTaken, 7), false)
	else
		if self.storage.settings.hardcoreMode then
			hudstat:setRenderString(string.format(" %d", self.storage.settings.hcHitsMax))
		else
			hudstat:setRenderString(" 0")
		end
		self.storage.hitsTaken = 0
		hudstat:setIconFrame("1", 0, false)
	end
end

mod.hudstat = hudstat
hudstat:init(mod)
hudstat:setRenderString(" 0")
hudstat.hudSprite:Load("gfx/hit_counter.anm2", true)
hudstat:setIconFrame("1", 0, false)

mod.playerKilled = false
mod.storage = {
	onceHit = false,
	hitsTaken = 0,
	hitsTakenFloor = 0,
	settings = {
		hardcoreMode = false,
		hcHitsMax = 5,
		funnyEffects = true,
		floorNoHitBonus = true,
		statBias = {
			X = 0,
			Y = 0
		}
	}
}

modConfigMenuInit()

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityDamage)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	local data = json.encode(mod.storage)
	mod:SaveData(data)
end)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	if mod.playerKilled and mod.storage.settings.funnyEffects then
		local sfxManager = SFXManager()
		if sfxManager:IsPlaying(SoundEffect.SOUND_ISAAC_HURT_GRUNT) then
			sfxManager:Stop(SoundEffect.SOUND_ISAAC_HURT_GRUNT)
		end

		if sfxManager:IsPlaying(SoundEffect.SOUND_ISAACDIES) then
			sfxManager:Stop(SoundEffect.SOUND_ISAACDIES)
		end
	end

	if mod.playerKilled and not Isaac.GetPlayer(0):IsDead() then
		mod.playerKilled = false
		print("gotcha rewinder :)")
		Isaac.GetPlayer(0):Die() --crashes game somehow
	end
end, EntityType.ENTITY_PLAYER)

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
	if mod.storage.settings.hardcoreMode and mod.storage.settings.floorNoHitBonus and mod.storage.hitsTakenFloor == 0 then
		if not (mod.storage.hitsTaken == 0) then
			hudstat:setDiff(true, "+1", 250)
		end
		mod.storage.hitsTaken = mod.storage.hitsTaken - 1 >= 0 and mod.storage.hitsTaken - 1 or 0
		hudstat:setRenderString(string.format(" %d", mod.storage.settings.hcHitsMax - mod.storage.hitsTaken))
		hudstat:setIconFrame("1", math.min(mod.storage.hitsTaken, 7), true)
	end

	mod.storage.hitsTakenFloor = 0
end)
