local HelpData = {
	overview = {
		title = "📋 Game Overview",
		content = [[Welcome to 'Pyramid'!

'Pyramid' is a tycoon game where you build your diorama empire and earn gold.

Your goal is to purchase dioramas that generate passive income, upgrade your skills, complete quests, and go through rebirths to earn permanent bonuses.

Core mechanics:
• Dioramas — source of passive income
• Gold — main game currency
• Levels — unlock new opportunities and rewards
• Upgrades — enhance your stats
• Quests — tasks with valuable rewards
• Rebirth — reset progress for a multiplier
• Backrooms — secret zone with adventures

Click on the content sections on the left to learn more about each mechanic!]]
	},
	dioramas = {
		title = "🏛️ Dioramas",
		content = [[Dioramas are the main source of income in the game.

How dioramas work:
• Each diorama generates gold every minute
• Income depends on the type and rarity of the diorama
• Gold accumulates in storage and needs to be collected

Purchasing dioramas:
• Approach an empty pedestal and click on it
• The diorama cost is displayed on the info panel
• The more expensive the diorama, the more income it brings

Diorama limit:
• You have a limit on the number of dioramas
• The limit can be increased through upgrades
• Current limit is shown at the top of the diorama panel

Diorama rarity:
• Common — base income
• Uncommon — increased income
• Rare — high income
• Epic — very high income
• Legendary — maximum income

Tip: Try to fill all available slots with dioramas to maximize passive income!]]
	},
	gold = {
		title = "💰 Gold and Storage",
		content = [[Gold is the main currency in the game.

How gold is earned:
• Passively — from dioramas every minute
• For completing quests
• As level rewards
• Bonus on rebirth

Gold storage:
• Gold from dioramas accumulates in storage
• Storage has limited capacity
• When storage is full, new income is not added!
• Current fill level is shown on the progress bar

Collecting gold:
• Click the 'Collect' button to claim gold from storage
• With the 'Auto-collect' upgrade, gold is collected automatically
• Collected gold is added to your balance

Increasing capacity:
• Upgrade 'Storage Capacity' in the Upgrades section
• This allows accumulating more gold without frequent collection

Double chance:
• The 'Double Chance' upgrade gives a probability to get x2 gold
• Works for both passive income and collection

Tip: Don't forget to collect gold regularly to avoid losing income due to storage overflow!]]
	},
	levels = {
		title = "⭐ Levels and Experience",
		content = [[The level system reflects your progress in the game.

Gaining experience:
• Experience (XP) is awarded for collecting gold
• XP is also given for completing quests
• The amount of XP depends on activity

Leveling up:
• When enough XP is accumulated, you advance to the next level
• Each level requires more XP
• New level notification appears on screen

Level rewards:
• At certain levels you receive rewards
• Rewards can be gold or special items
• Check the 'Level' section in the game hub
• Rewards with green border are available to claim
• Click on a reward to claim it

Skill points:
• You receive skill points for each level
• Skill points are spent on upgrades
• The higher the level, the more points

Tip: Actively collect gold and complete quests to level up faster and earn rewards!]]
	},
	upgrades = {
		title = "⬆️ Upgrades",
		content = [[Upgrades enhance your stats and make the game more efficient.

Types of upgrades:

💰 Gold Per Minute
• Increases the amount of gold each diorama generates
• Cost increases with each upgrade level
• One of the most important upgrades for progress

📦 Storage Capacity
• Increases the maximum amount of gold in storage
• Allows less frequent manual collection

🎲 Double Chance
• Gives a probability to get double income
• Percentage increases with each level

📜 Quest Bonus
• Increases rewards for completing quests
• Both gold and quest XP are increased

🤖 Auto Collect
• Automatically collects gold from storage
• One-time upgrade — either you have it or not

Upgrade costs:
• Each upgrade costs gold and skill points
• Price increases exponentially with level
• If resources are insufficient — button is inactive

Tip: First invest in 'Gold Per Minute' and 'Storage Capacity' — this is the foundation for stable progress!]]
	},
	quests = {
		title = "📜 Quests",
		content = [[Quests are tasks that reward you with gold and experience.

How quests work:
• You always have several active quests
• Quests refresh automatically after a certain time
• You can skip an unwanted quest

Quest types:
• Item collection — find and collect specific items on the map

Item collection mechanics:
• Click — click on the item with your mouse (requires ClickDetector)
• Hold — approach and hold the button (ProximityPrompt)
• Touch — simply walk through the item

Quest rarity:
• Common — base rewards
• Uncommon — improved rewards
• Rare — valuable rewards
• Epic — very valuable rewards
• Legendary — maximum rewards

Claiming rewards:
• When a quest is complete, click '🎁 Claim'
• Reward: gold + XP
• Quest bonus increases the reward amount

Quest refresh:
• Countdown timer shows time until refresh
• After refresh, new quests appear

Tip: Complete higher rarity quests first — they give better rewards!]]
	},
	prestige = {
		title = "✨ Rebirth",
		content = [[Rebirth (prestige) is a progress reset for a permanent bonus.

How rebirth works:
• Available when reaching a certain level (usually 90+)
• On rebirth, your level, gold, and upgrades are reset
• Dioramas are also reset

What you get:
• Permanent income multiplier (+5% per rebirth)
• Gold multiplier from dioramas (+3% per rebirth)
• Donation bonus multiplier (+2% per rebirth)
• Each bonus stacks and lasts forever

Bonus formulas:
• Income: Base multiplier + (prestige level × 5%)
• Dioramas: prestige level × 3%
• Donation: prestige level × 2%
• Example: 1 rebirth = +15% income, +3% dioramas, +2% donation

When to rebirth:
• When progress slows down and level is high
• When the rebirth bonus will significantly speed up the new cycle
• The higher the prestige level, the faster the game will progress

What is preserved:
• Prestige level and its multiplier
• Purchased GamePasses and premium items

What is reset:
• Level and experience
• Gold and storage
• Upgrades and skill points
• Dioramas

Tip: Don't rush into rebirth! Make sure the bonus will significantly speed up your progress in the next cycle.]]
	},
	backrooms = {
		title = "🚪 Backrooms",
		content = [[Backrooms is a secret zone with a maze of corridors.

How to enter:
• Find the Backrooms entrance on the map
• Enter the teleportation zone

What's inside:
• Endless corridors and rooms
• The zone consists of several sections (A, B, C)
• There are teleportation zones between sections

Navigation:
• Explore the corridors and look for transitions
• Teleportation zones move you between sections
• Look for the exit to return to the main map

Why go to Backrooms:
• Unique exploration experience
• Possible secrets and rewards
• Atmospheric adventure

Tip: Remember your route — corridors can be confusing! Look for the exit door to return back.]]
	},
}

return HelpData