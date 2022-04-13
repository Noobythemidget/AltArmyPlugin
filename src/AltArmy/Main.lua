--
-- This plugin saves character data to a file whenever the plugin loads/unloads or the character levels up.
-- The type of data saved is:
-- character name, level, race, class, money and other wallet items.
--
-- It will keep track of when each character was last updated (your last login) and when it last leveled up.
-- 
-- The intention is for the file to be parsed by an external application so you can view this character data offline.
--
-- by Nubi of Gladden

import "Turbine";
import "Turbine.Gameplay";

-------------------------------------------------------
-------------------------------------------------------

-- burgled from AltInventory plugin by Garan
-- need localPlayer to test for session play
localPlayer=Turbine.Gameplay.LocalPlayer.GetInstance();
-- mmediately test for session play BEFORE so that we can safely bail without loading any data and without any handlers
if string.sub(localPlayer:GetName(),1,1)=="~" then
	-- do not load if the character is a session play character
	Turbine.Shell.WriteLine(PLUGIN_NAME .." does not support session play characters.");
	return
end

-- begin event handler utility functions
function AddCallback(object, event, callback)
	if (object[event] == nil) then
		object[event] = callback;
	else
		if (type(object[event]) == "table") then
			local exists=false;
			local k,v;
			for k,v in ipairs(object[event]) do
				if v==callback then
					exists=true;
					break;
				end
			end
			if not exists then
				table.insert(object[event], callback);
			end
		else
			if object[event]~=callback then
				object[event] = {object[event], callback};
			end
		end
	end
	return callback;
end

-- safely remove a callback without clobbering any extras
function RemoveCallback(object, event, callback)
    if (object[event] == callback) then
        object[event] = nil;
    else
        if (type(object[event]) == "table") then
            local size = table.getn(object[event]);
            for i = 1, size do
                if (object[event][i] == callback) then
                    table.remove(object[event], i);
                    break;
                end
            end
        end
    end
end
-- end event handler utility functions
-- end burgle

-------------------------------------------------------
-------------------------------------------------------

-- constants for plugin info
PLUGIN_NAME = "AltArmy";
PLUGIN_VERSION = 0.1;
-- constants for table keys
ACCOUNT_WALLET_KEY = "AccountWallet";
PERSONAL_WALLET_KEY = "PersonalWallet";
WALLET_ITEM_DESCRIPTIONS_KEY = "WalletItemDescriptions";
CHARACTER_LIST_KEY = "CharacterList";
LAST_UPDATED_KEY  = "LastUpdated";
LAST_LEVEL_CHANGE_KEY = "LastLevelChange";
PLUGIN_VERSION_KEY = "PluginVersion";

VOCATION_KEY = "Vocation";
PROFESSIONS_KEY = "Professions";
PROFICIENCY_KEY = "Proficiency";
MASTERY_KEY = "Mastery";
CRAFTING_KEY = "Crafting";
STATS_KEY = "Stats"


-- mapping class enumerations to strings
CLASSES = {
  [Turbine.Gameplay.Class.Beorning] = "Beorning",
  [Turbine.Gameplay.Class.Burglar] = "Burglar",
  [Turbine.Gameplay.Class.Captain] = "Captain",
  [Turbine.Gameplay.Class.Champion] = "Champion",
  [Turbine.Gameplay.Class.Guardian] = "Guardian",
  [Turbine.Gameplay.Class.Hunter] = "Hunter",
  [Turbine.Gameplay.Class.LoreMaster] = "Lore Master",
  [Turbine.Gameplay.Class.Minstrel] = "Minstrel",
  [Turbine.Gameplay.Class.RuneKeeper] = "Rune-Keeper",
  [Turbine.Gameplay.Class.Warden] = "Warden",

  [Turbine.Gameplay.Class.BlackArrow] = "BlackArrow",
  [Turbine.Gameplay.Class.Defiler] = "Defiler",
  [Turbine.Gameplay.Class.Reaver] = "Reaver",
  [Turbine.Gameplay.Class.Stalker] = "Stalker",
  [Turbine.Gameplay.Class.Troll] = "Troll",
  [Turbine.Gameplay.Class.WarLeader] = "WarLeader",
  [Turbine.Gameplay.Class.Weaver] = "Weaver",

  [Turbine.Gameplay.Class.Chicken] = "Chicken",
  [Turbine.Gameplay.Class.Ranger] = "Ranger",

  [Turbine.Gameplay.Class.Undefined] = "Undefined"
}
-- mapping race enumerations to strings
RACES = {
  [Turbine.Gameplay.Race.Beorning] = "Beorning",
  [Turbine.Gameplay.Race.Dwarf] = "Dwarf",
  [Turbine.Gameplay.Race.Elf] = "Elf",
  [Turbine.Gameplay.Race.HighElf] = "HighElf",
  [Turbine.Gameplay.Race.Hobbit] = "Hobbit",
  [Turbine.Gameplay.Race.Man] = "Man",
  [Turbine.Gameplay.Race.StoutAxe] = "StoutAxe",

  [Turbine.Gameplay.Race.Undefined] = "Undefined"
}
-- mapping alignment enumerations to strings
ALIGNMENTS = {
  [Turbine.Gameplay.Alignment.FreePeople] = "Free People",
  [Turbine.Gameplay.Alignment.MonsterPlayer] = "Monster Player",

  [Turbine.Gameplay.Alignment.Undefined] = "Undefined"
}

-- mapping craft tier enumerations to strings
-- not using Turbine.Gameplay.CraftTier.Apprentice etc enums 
-- since the I am using proficiency/mastery Level to map to craft tier
-- this method does not return an enum, only the equivalent number.
-- the enums don't seem to have all the tiers either
CRAFT_TIERS = {
  ["0"] = "Undefined",
  ["1"] = "Apprentice",
  ["2"] = "Journeyman",
  ["3"] = "Expert",
  ["4"] = "Artisan",
  ["5"] = "Master",
  ["6"] = "Supreme",
  ["7"] = "Westfold",
  ["8"] = "Eastemnet",
  ["9"] = "Westemnet",
  ["10"] = "Anórien", -- latin ó with acute
  ["11"] = "Doomfold",
  ["12"] = "Ironfold",
  ["13"] = "Minas Ithil",
  ["14"] = "Gundabad",
}

-- mapping vocation enumerations to strings
VOCATIONS = {
  [Turbine.Gameplay.Vocation.None] = "None",
  [Turbine.Gameplay.Vocation.Explorer] = "Explorer",
  [Turbine.Gameplay.Vocation.Tinker] = "Tinker",
  [Turbine.Gameplay.Vocation.Yeoman] = "Yeoman",
  [Turbine.Gameplay.Vocation.Historian] = "Historian",
  [Turbine.Gameplay.Vocation.Armsman] = "Armsman",
  [Turbine.Gameplay.Vocation.Woodsman] = "Woodsman",
  [Turbine.Gameplay.Vocation.Armorer] = "Armorer"
}
-- mapping profession enumerations to strings
PROFESSIONS = {
  [Turbine.Gameplay.Profession.Cook] = "Cook",
  [Turbine.Gameplay.Profession.Farmer] = "Farmer",
  [Turbine.Gameplay.Profession.Forester] = "Forester",
  [Turbine.Gameplay.Profession.Jeweller] = "Jeweller",
  [Turbine.Gameplay.Profession.Metalsmith] = "Metalsmith",
  [Turbine.Gameplay.Profession.Prospector] = "Prospector",
  [Turbine.Gameplay.Profession.Scholar] = "Scholar",
  [Turbine.Gameplay.Profession.Tailor] = "Tailor",
  [Turbine.Gameplay.Profession.Undefined] = "Undefined",
  [Turbine.Gameplay.Profession.Weaponsmith] = "Weaponsmith",
  [Turbine.Gameplay.Profession.Woodworker] = "Woodworker"
}
-- mapping vocation enumerations to their profession enumerations
VOCATIONS_TO_PROFESSIONS = {
  [Turbine.Gameplay.Vocation.None] = {  }, -- None
  [Turbine.Gameplay.Vocation.Explorer] = {  -- Explorer
    Turbine.Gameplay.Profession.Tailor, 
		Turbine.Gameplay.Profession.Forester, 
		Turbine.Gameplay.Profession.Prospector 
  },
  [Turbine.Gameplay.Vocation.Tinker] = { -- Tinker
    Turbine.Gameplay.Profession.Jeweller,
    Turbine.Gameplay.Profession.Prospector,
    Turbine.Gameplay.Profession.Cook 
  },
  [Turbine.Gameplay.Vocation.Yeoman] = { -- Yeoman
    Turbine.Gameplay.Profession.Cook, 
		Turbine.Gameplay.Profession.Farmer, 
		Turbine.Gameplay.Profession.Tailor 
  },
  [Turbine.Gameplay.Vocation.Historian] = { -- Historian
    Turbine.Gameplay.Profession.Scholar, 
		Turbine.Gameplay.Profession.Farmer, 
		Turbine.Gameplay.Profession.Weaponsmith 
  },
  [Turbine.Gameplay.Vocation.Armsman] = { -- Armsman
    Turbine.Gameplay.Profession.Weaponsmith, 
    Turbine.Gameplay.Profession.Prospector, 
    Turbine.Gameplay.Profession.Woodworker 
  },
  [Turbine.Gameplay.Vocation.Woodsman] = { -- Woodsman
    Turbine.Gameplay.Profession.Woodworker, 
    Turbine.Gameplay.Profession.Forester, 
    Turbine.Gameplay.Profession.Farmer 
  },
  [Turbine.Gameplay.Vocation.Armorer] = { -- Armorer
    Turbine.Gameplay.Profession.Metalsmith, 
    Turbine.Gameplay.Profession.Prospector, 
    Turbine.Gameplay.Profession.Tailor 
  }
}

-- utility functions for retrieving mapped values
-- given class enum, returns the string value
function GetClassName(classEnum)
  if (CLASSES[classEnum] == nil)
  then
    return CLASSES[Turbine.Gameplay.Class.Undefined];
  else
    return CLASSES[classEnum];
  end
end

-- given race enum, returns the string value
function GetRaceName(raceEnum)
  if (RACES[raceEnum] == nil)
  then
    return RACES[Turbine.Gameplay.Race.Undefined];
  else
    return RACES[raceEnum];
  end
end

-- given alignment enum, returns the string value
function GetAlignmentName(alignmentEnum)
  if (ALIGNMENTS[alignmentEnum] == nil)
  then
    return ALIGNMENTS[Turbine.Gameplay.Alignment.Undefined];
  else
    return ALIGNMENTS[alignmentEnum];
  end
end

-- given craft tier enum, returns the string value
function GetCraftTierName(craftTierEnum)
  if (CRAFT_TIERS[craftTierEnum] == nil)
  then
    return CRAFT_TIERS[Turbine.Gameplay.CraftTier.Undefined];
  else
    return CRAFT_TIERS[craftTierEnum];
  end
end

-- given vocation enum, returns the string value
function GetVocationName(vocationEnum)
  if (VOCATIONS[vocationEnum] == nil)
  then
    return VOCATIONS[Turbine.Gameplay.Vocation.None];
  else
    return VOCATIONS[vocationEnum];
  end
end

-- given profession enum, returns the string value
function GetProfessionName(professionEnum)
  if (PROFESSIONS[professionEnum] == nil)
  then
    return PROFESSIONS[Turbine.Gameplay.Profession.Undefined];
  else
    return PROFESSIONS[professionEnum];
  end
end

function GetProfessionsFromVocation(vocationEnum)
  if (VOCATIONS_TO_PROFESSIONS[vocationEnum] == nil)
  then
    return VOCATIONS_TO_PROFESSIONS[Turbine.Gameplay.Vocation.None]
  else
    return VOCATIONS_TO_PROFESSIONS[vocationEnum]
  end
end

-- returns a table with following keys: AccountWallet, PersonalWallet, WalletItemDescriptions
-- each with a table of the respective item names as keys and quantity or item description as values.
function GetCraftingData()
  --[[
  vocation: 'Armsman',
  professions: [ 
    Weaponsmith: {},
    Woodworker: {}, 
    Prospector: {}
  ]

  ]]--
  local data = { [PROFESSIONS_KEY] = {} };
  local vocation = localPlayer:GetAttributes():GetVocation()

  data[VOCATION_KEY] = GetVocationName(vocation)

  for k,v in pairs(VOCATIONS_TO_PROFESSIONS[vocation])
  do
    -- k is just an index since the value is an array
    professionName = GetProfessionName(v)
    data[PROFESSIONS_KEY][professionName] = GetProfessionData(v)

  end
  
  return data
end

--[[
   {
      proficiency: {
        name: 'Minas Ithil',
        title: ''
        level: '13'
        xp: 0,
        xpTarget: 630,
      },
      mastery: {
        name: 'Minas Ithil',
        title: '',
        level: 13,
        xp: 0,
        xpTarget: 1260
      }
    },
]]--
function GetProfessionData(professionEnum)
  local data = { [PROFICIENCY_KEY] = {}, [MASTERY_KEY] = {} }

  local pi = localPlayer:GetAttributes():GetProfessionInfo(professionEnum);

  local pLevel = tostring(math.floor(pi:GetProficiencyLevel()))
  local mLevel = tostring(math.floor(pi:GetMasteryLevel()))

  data[PROFICIENCY_KEY] = {
    Name = GetCraftTierName(pLevel),
    Title = pi:GetProficiencyTitle(),
    Level = pLevel,
    Exp = tostring(math.floor(pi:GetProficiencyExperience())),
    ExpTarget = tostring(math.floor(pi:GetProficiencyExperienceTarget()))
  }
  data[MASTERY_KEY] = {
    Name = GetCraftTierName(mLevel),
    Title = pi:GetMasteryTitle(),
    Level = mLevel,
    Exp = tostring(math.floor(pi:GetMasteryExperience())),
    ExpTarget = tostring(math.floor(pi:GetMasteryExperienceTarget()))
  }

  return data
end


-- utility function to prepend a zero to single digit numbers (to make date/time pretty)
function prependZero(n)
  if (type(n) == "number" and n < 10 and n >= 0)
  then
    return "0" .. n;
  else
    return n;
  end
end

-- returns a nicely formatted current date/time
function GetCurrentDate()
  local dateTable = Turbine.Engine.GetDate();

  local year = math.floor(dateTable['Year']);
  local month = prependZero(math.floor(dateTable['Month']));
  local day = prependZero(math.floor(dateTable['Day']));
  local hour = prependZero(math.floor(dateTable['Hour']));
  local minute = prependZero(math.floor(dateTable['Minute']));
  local second = prependZero(math.floor(dateTable['Second']));

  local str = year .. "/" .. month .. "/" .. day .. " " .. hour .. ":" .. minute .. ":" .. second;
  return str;
end

-- returns a table with following keys: AccountWallet, PersonalWallet, WalletItemDescriptions
-- each with a table of the respective item names as keys and quantity or item description as values.
function GetWalletItems()
  local data = { [ACCOUNT_WALLET_KEY] = {}, [PERSONAL_WALLET_KEY] = {}, [WALLET_ITEM_DESCRIPTIONS_KEY] = {} };
  
  local wallet = localPlayer:GetWallet();
  for i=1, wallet:GetSize() 
  do
    walletItem = wallet:GetItem(i);
    if(walletItem ~= nil)
    then
      local itemName = walletItem:GetName();
      local itemQty = tostring(math.floor(walletItem:GetQuantity()));
      local itemDesc = walletItem:GetDescription();

      data[WALLET_ITEM_DESCRIPTIONS_KEY][itemName] = itemDesc;
      if(walletItem:IsAccountItem())
      then
        data[ACCOUNT_WALLET_KEY][itemName] = itemQty;
      else
        data[PERSONAL_WALLET_KEY][itemName] = itemQty;
      end
    end
  end

  return data;
end

--
function GetMonsterCharacterStats()
local data = {
  --  MoneyComponents = localPlayer:GetAttributes():GetMoneyComponents(),
    DestinyPoints = localPlayer:GetAttributes():GetDestinyPoints()
};

return data;
end

-- returns a table with character stats like morale, vitality, etc
function GetCharacterStats()
  local data = {
    MaxMorale = localPlayer:GetMaxMorale(),
    MaxPower = localPlayer:GetMaxPower(),
    BaseMaxMorale = localPlayer:GetBaseMaxMorale(),
    BaseMaxPower = localPlayer:GetBaseMaxPower(),

    -- these are common for monster players and free peoples players
    -- MoneyComponents = localPlayer:GetAttributes():GetMoneyComponents(),
    DestinyPoints = localPlayer:GetAttributes():GetDestinyPoints(),

    -- the attributes might not work for monster players as they come from FreePeopleAttributes
    AcidMitigation = localPlayer:GetAttributes():GetAcidMitigation(),
    Agility = localPlayer:GetAttributes():GetAgility(),
    Armor = localPlayer:GetAttributes():GetArmor(),
    BaseAgility = localPlayer:GetAttributes():GetBaseAgility(),
    BaseArmor = localPlayer:GetAttributes():GetBaseArmor(),
    BaseCriticalHitAvoidance = localPlayer:GetAttributes():GetBaseCriticalHitAvoidance(),
    BaseCriticalHitChance = localPlayer:GetAttributes():GetBaseCriticalHitChance(),
    BaseFate = localPlayer:GetAttributes():GetBaseFate(),
    BaseMight = localPlayer:GetAttributes():GetBaseMight(),
    BaseResistance = localPlayer:GetAttributes():GetBaseResistance(),
    BaseVitality = localPlayer:GetAttributes():GetBaseVitality(),
    BaseWill = localPlayer:GetAttributes():GetBaseWill(),
    Block = localPlayer:GetAttributes():GetBlock(),
    CommonMitigation = localPlayer:GetAttributes():GetCommonMitigation(),
    DiseaseResistance = localPlayer:GetAttributes():GetDiseaseResistance(),
    Evade = localPlayer:GetAttributes():GetEvade(),
    Fate = localPlayer:GetAttributes():GetFate(),
    FearResistance = localPlayer:GetAttributes():GetFearResistance(),
    Finesse = localPlayer:GetAttributes():GetFinesse(),
    FireMitigation = localPlayer:GetAttributes():GetFireMitigation(),
    FrostMitigation = localPlayer:GetAttributes():GetFrostMitigation(),
    InCombatMoraleRegeneration = localPlayer:GetAttributes():GetInCombatMoraleRegeneration(),
    InCombatPowerRegeneration = localPlayer:GetAttributes():GetInCombatPowerRegeneration(),
    IncomingHealing = localPlayer:GetAttributes():GetIncomingHealing(),
    LightningMitigation = localPlayer:GetAttributes():GetLightningMitigation(),
    MeleeCriticalHitAvoidance = localPlayer:GetAttributes():GetMeleeCriticalHitAvoidance(),
    MeleeCriticalHitChance = localPlayer:GetAttributes():GetMeleeCriticalHitChance(),
    MeleeDamage = localPlayer:GetAttributes():GetMeleeDamage(),
    MeleeDefence = localPlayer:GetAttributes():GetMeleeDefence(),
    Might = localPlayer:GetAttributes():GetMight(),
    OutgoingHealing = localPlayer:GetAttributes():GetOutgoingHealing(),
    OutOfCombatMoraleRegeneration = localPlayer:GetAttributes():GetOutOfCombatMoraleRegeneration(),
    OutOfCombatPowerRegeneration = localPlayer:GetAttributes():GetOutOfCombatPowerRegeneration(),
    Parry = localPlayer:GetAttributes():GetParry(),
    PhysicalMitigation = localPlayer:GetAttributes():GetPhysicalMitigation(),
    PoisonResistance = localPlayer:GetAttributes():GetPoisonResistance(),
    RangeCriticalHitAvoidance = localPlayer:GetAttributes():GetRangeCriticalHitAvoidance(),
    RangeCriticalHitChance = localPlayer:GetAttributes():GetRangeCriticalHitChance(),
    RangeDamage = localPlayer:GetAttributes():GetRangeDamage(),
    RangeDefence = localPlayer:GetAttributes():GetRangeDefence(),
    ShadowMitigation = localPlayer:GetAttributes():GetShadowMitigation(),
    TacticalCriticalHitAvoidance = localPlayer:GetAttributes():GetTacticalCriticalHitAvoidance(),
    TacticalCriticalHitChance = localPlayer:GetAttributes():GetTacticalCriticalHitChance(),
    TacticalDamage = localPlayer:GetAttributes():GetTacticalDamage(),
    TacticalDefence = localPlayer:GetAttributes():GetTacticalDefence(),
    TacticalMitigation = localPlayer:GetAttributes():GetTacticalMitigation(),
    Vitality = localPlayer:GetAttributes():GetVitality(),
    Will = localPlayer:GetAttributes():GetWill(),
    WoundResistance = localPlayer:GetAttributes():GetWoundResistance ()
  };

  return data;
end

-- simple callback for saving data call
function dataSaveCallback(success, errMsg)
  if (not success)
  then
    Turbine.Shell.WriteLine("Save Failed: "..errMsg);
  end
end

-- simple callback for loading data call
function dataLoadCallback(success, errMsg)
  if (not success)
  then
    Turbine.Shell.WriteLine("Load Failed: "..errMsg);
  end
end

-- loads the existing plugindata file
function LoadPluginData()
  local data = Turbine.PluginData.Load(Turbine.DataScope.Server, PLUGIN_NAME, dataLoadCallBack);
  if(data == nil)
  then
    data = { [WALLET_ITEM_DESCRIPTIONS_KEY] = {}, [ACCOUNT_WALLET_KEY] = {}, [CHARACTER_LIST_KEY] = {} };
  end
  return data;
end

-- saves the character data to the plugindata file
-- isLevelChanged is true when this call is triggered from a LevelChanged event. it is false otherwise.
function SavePluginData(isLevelChanged)
--  local data = LoadPluginData();
  
  -- the  player info we want
  local charName = localPlayer:GetName();
  local charLevel = localPlayer:GetLevel();
  local charClass = GetClassName(localPlayer:GetClass());
  local charRace = GetRaceName(localPlayer:GetRace());
  local charAlignment = GetAlignmentName(localPlayer:GetAlignment());
  local charMoney = localPlayer:GetAttributes():GetMoney();
  local curDate = GetCurrentDate();
  local stats = nil;
  local crafting = nil;
  if (charAlignment ~= 'Monster Player') 
  then
    crafting = GetCraftingData()
    stats = GetCharacterStats()
  else
    stats = GetMonsterCharacterStats()
  end

  -- if responding to a level change event, use current date for last leveled
  -- otherwise keep the old value if it exists 
  -- (ignore for characters with level 1 as existing value could be from a previously deleted character with the same name)
  local lastLeveled = nil;
  if (isLevelChanged)
  then
    lastLeveled = curDate;
  elseif (charLevel > 1 and 
          data[CHARACTER_LIST_KEY][charName] ~= nill and 
          data[CHARACTER_LIST_KEY][charName][LAST_LEVEL_CHANGE_KEY] ~= nil)
  then
    lastLeveled = data[CHARACTER_LIST_KEY][charName][LAST_LEVEL_CHANGE_KEY];
  end

  -- get the player's wallet
  local wallet = GetWalletItems();
  -- update item descriptions section of the data table
  for k,v in pairs(wallet[WALLET_ITEM_DESCRIPTIONS_KEY])
  do
    if(k ~= nil and v ~= nil)
    then
      data[WALLET_ITEM_DESCRIPTIONS_KEY][k] = v;
    end
  end
  -- update account items section of the data table
  for k,v in pairs(wallet[ACCOUNT_WALLET_KEY])
  do
    if(k ~= nil and v ~= nil)
    then
      data[ACCOUNT_WALLET_KEY][k] = v;
    end
    data[ACCOUNT_WALLET_KEY][LAST_UPDATED_KEY] = curDate;
  end

  -- create/update the character's entry in the data table
  data[CHARACTER_LIST_KEY][charName] = { 
    Level = tostring(math.floor(charLevel)), 
    Class = charClass, 
    Race = charRace,
    Alignment = charAlignment, 
    LastLevelChange = lastLeveled,
    [LAST_UPDATED_KEY] = curDate, 
    [PLUGIN_VERSION_KEY] = tostring(PLUGIN_VERSION),
    Money = tostring(math.floor(charMoney)),
    [PERSONAL_WALLET_KEY] = wallet[PERSONAL_WALLET_KEY],
    [CRAFTING_KEY] = crafting,
    [STATS_KEY] = stats
  };

  --  write it to the plugindata file
  Turbine.PluginData.Save(Turbine.DataScope.Server, PLUGIN_NAME, data, dataSaveCallback);
end

-- event callback wrappers
function LoadUnloadEventHandler()
  SavePluginData(false);
end

function LevelChangedEventHandler()
  SavePluginData(true);
end

-------------------------------------------------------
-------------------------------------------------------
-- Main part
-------------------------------------------------------
-------------------------------------------------------
Turbine.Shell.WriteLine(PLUGIN_NAME .. " v" .. PLUGIN_VERSION .. " by Nubi loaded.");
data = LoadPluginData();

-- login
AddCallback(Turbine.Plugin, "Load", LoadUnloadEventHandler);
-- logout
AddCallback(Turbine.Plugin, "Unload", LoadUnloadEventHandler);
-- level change
AddCallback(localPlayer, "LevelChanged", LevelChangedEventHandler);