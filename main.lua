HitCounter = RegisterMod("Hit Counter by nancex", 1)
local mod = HitCounter
local hudstat = require("hudstat")
local json = require("json")

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

hudstat:init(mod)
hudstat:setRenderString(" 0")
hudstat.hudSprite:Load("gfx/hit_counter.anm2", true)
hudstat:setIconFrame("1", 0, false)

mod.storage = {}
mod.storage.hitsTaken = 0

function mod:onEntityDamage(entity, amount, flags, source, countdown)
	if entity:ToPlayer() and not isSelfDamage(flags) then
		mod.storage.hitsTaken = mod.storage.hitsTaken + 1
		hudstat:setDiff(false, "+1", 60)
		hudstat:setRenderString(string.format(" %d", mod.storage.hitsTaken))
		hudstat:setIconFrame("1", math.min(mod.storage.hitsTaken, 7), true)
	end
	return nil
end

function mod:onGameStarted(continued)
	if continued then
		local data = self:LoadData()
		if data then
			self.storage = json.decode(data)
			local hitsTaken = self.storage.hitsTaken
			hudstat:setRenderString(string.format(" %d", hitsTaken))
			hudstat:setIconFrame("1", math.min(hitsTaken, 7), false)
		end
	else
		self.storage = { hitsTaken = 0 }
		hudstat:setRenderString(" 0")
		hudstat:setIconFrame("1", 0, false)
	end
end

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityDamage)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	mod:SaveData(json.encode(mod.storage))
end)
