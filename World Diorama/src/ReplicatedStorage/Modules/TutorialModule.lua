-- TutorialModule — данные этапов обучения
-- Каждый шаг содержит:
--   id: уникальный идентификатор
--   message: текст сообщения для игрока
--   advanceType: "button" | "event" | "gui_enabled" | "gui_disabled" | "gui_visible" — способ перехода к следующему шагу
--   expectedEvent: (для advanceType="event") имя события от сервера
--   eventFilter: (для advanceType="event") функция-фильтр для проверки аргументов события
--   guiName: (для advanceType="gui_enabled", "gui_disabled") имя ScreenGui в PlayerGui
--   guiPath: (для advanceType="gui_visible") путь к GUI-элементу в PlayerGui для проверки Visible
--   highlightPath: (опционально) путь к элементу в PlayerGui для подсветки
--   arrowDirection: (опционально) "down" | "up" | "left" | "right" — направление стрелки
--   nextButtonText: текст кнопки перехода (по умолчанию "Далее")
--   messagePosition: (опционально) "bottom" | "top" — позиция MessageBox на экране (по умолчанию "bottom")

return {
	steps = {
		{
			id = "welcome",
			message = "Welcome to 'Pyramid'! This is a tycoon game where you build a diorama empire and earn gold.",
			advanceType = "button",
			nextButtonText = "Next",
		},
		{
			id = "purpose",
			message = "Dioramas are your main source of income. Each diorama generates gold every minute. The more dioramas — the more income!",
			advanceType = "button",
			nextButtonText = "Next",
		},
		{
			id = "mechanics",
			message = "Upgrade skills, complete quests, and rebirth for permanent bonuses",
			advanceType = "button",
			nextButtonText = "Next",
		},
		{
			id = "collect_gold",
			message = "Click the button on the left side of the screen or press 'E' on your keyboard to open the gold collection menu",
			advanceType = "gui_enabled",
			guiName = "GoldAccumulationGui",
			highlightPath = "TopBar.LeftButtons.GoldButton",
			arrowDirection = "down",
		},
		{
			id = "collect_gold_2",
			message = "Here you can see how much gold has been accumulated",
			advanceType = "button",
			nextButtonText = "Next",
			highlightPath = "GoldAccumulationGui.MainContainer.StoragePanel.ProgressContainer",
			arrowDirection = "down",
			watchVisiblePath = "GoldAccumulationGui.MainContainer",
    		rollbackStepId = "collect_gold"
		},
		{
			id = "collect_gold_3",
			message = "Click the 'Collect' button to claim your accumulated gold.",
			advanceType = "event",
			expectedEvent = "GoldCollected",
			eventFilter = function(success, message)
				return true
			end,
			highlightPath = "GoldAccumulationGui.MainContainer.StoragePanel.ProgressContainer.CollectButton",
			arrowDirection = "down",
			watchVisiblePath = "GoldAccumulationGui.MainContainer",
    		rollbackStepId = "collect_gold"
		},
		{
			id = "collect_gold_4",
			message = "Here you will see your purchased dioramas and how much gold they have accumulated.",
			advanceType = "button",
			nextButtonText = "Next",
			highlightPath = "GoldAccumulationGui.MainContainer.DioramaList",
			arrowDirection = "down",
			messagePosition = "top",
			watchVisiblePath = "GoldAccumulationGui.MainContainer",
    		rollbackStepId = "collect_gold"

		},
		{
			id = "collect_gold_5",
			message = "Great! Now close the window to continue.",
    		advanceType = "gui_disabled",
    		guiName = "GoldAccumulationGui",
			highlightPath = "GoldAccumulationGui.MainContainer.Title.CloseButton",
			arrowDirection = "down",
		},
		{
			id = "open_hub",
			message = "Click the button on the left side of the screen or press 'Q' on your keyboard to open the game hub.",
			advanceType = "gui_enabled",
			guiName = "GameHubGui",
			highlightPath = "TopBar.LeftButtons.ManageButton",
			arrowDirection = "down",
		},
		{
			id = "level",
			message = "Here you can find information about your level and stats",
			advanceType = "button",
			nextButtonText = "Next",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.LevelCard",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "level_2",
			message = "Here you can find information about rebirth and its bonuses",
			advanceType = "button",
			nextButtonText = "Next",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.RebirthCard",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "level_3",
			message = "Here you can find information about rewards for your level",
			advanceType = "button",
			nextButtonText = "Next",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.AwardCard",
			arrowDirection = "down",
			messagePosition = "top",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "upgrades",
			message = "Click the button to open the upgrades panel",
			advanceType = "gui_visible",
    		guiPath = "GameHubGui.MainContainer.ContentContainer.UpgradesPane",
			highlightPath = "GameHubGui.MainContainer.Header.TabsPanel.upgradesTab",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "upgrades_2",
			message = "Here you will upgrade your stats",
			advanceType = "button",
			nextButtonText = "Next",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests",
			message = "Click the button to open the quests panel",
			advanceType = "gui_visible",
    		guiPath = "GameHubGui.MainContainer.ContentContainer.QuestsPane",
			highlightPath = "GameHubGui.MainContainer.Header.TabsPanel.questsTab",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests_2",
			message = "Complete quests to earn gold and increase your level",
			advanceType = "button",
			nextButtonText = "Next",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests_3",
			message = "Great! Now close the window to continue.",
    		advanceType = "gui_disabled",
    		guiName = "GameHubGui",
			highlightPath = "GameHubGui.MainContainer.Header.CloseButton",
			arrowDirection = "down",
		},
		{
			id = "go_to_diorama",
			message = "Approach any diorama stand and press 'E' to open the purchase interface.",
			advanceType = "event",
			expectedEvent = "ShowDioramaGUI",
			eventFilter = function(dioramaId, data)
				return true
			end,
		},
		{
			id = "buy_diorama",
			message = "In this menu you can purchase a diorama for gold, or for Robux if the owner has listed it for sale.",
			advanceType = "button",
			nextButtonText = "Next",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "buy_diorama_2",
			message = "Click the button to open the voting panel",
			advanceType = "gui_visible",
    		guiPath = "PurchaseGui.MainFrame.Content.TabContent.Tab2Content.VotingSection",
			highlightPath = "PurchaseGui.MainFrame.TopBar.TabBar.TabButtons.Tab2",
			arrowDirection = "down",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "buy_diorama_3",
			message = "Vote for dioramas you like and against those you don't. Your vote affects the diorama's price. The higher the rating, the higher the price, and vice versa.",
			advanceType = "button",
			nextButtonText = "Next",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "complete",
			message = "Tutorial complete! Now you know the basics.",
			advanceType = "button",
			nextButtonText = "Done",
		},
	},
}