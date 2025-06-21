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
    player:Die()
end


trueDeath()
local player = Isaac.GetPlayer(0)
Game():BombExplosionEffects(player.Position, 300, TearFlags.TEAR_GIGA_BOMB, Color.Default, player, 1, true, false,
    DamageFlag.DAMAGE_EXPLOSION)
