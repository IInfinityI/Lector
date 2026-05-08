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
			message = "Добро пожаловать в «Пирамида»! Это игра-тайкун, где вы строите империю диорам и зарабатываете золото.",
			advanceType = "button",
			nextButtonText = "Далее",
		},
		{
			id = "purpose",
			message = "Диорамы — ваш главный источник дохода. Каждая диорама генерирует золото каждую минуту. Чем больше диорам — тем больше доход!",
			advanceType = "button",
			nextButtonText = "Далее",
		},
		{
			id = "mechanics",
			message = "Улучшайте навыки, выполняйте квесты и перерождайтесь для постоянных бонусов",
			advanceType = "button",
			nextButtonText = "Далее",
		},
		{
			id = "collect_gold",
			message = "Нажмите на кнопку в левой части экрана или на клавиатуре «E», чтобы открыть меню сбора накопленного золота",
			advanceType = "gui_enabled",
			guiName = "GoldAccumulationGui",
			highlightPath = "TopBar.LeftButtons.GoldButton",
			arrowDirection = "down",
		},
		{
			id = "collect_gold_2",
			message = "Здесь отображается сколько золото было накопленно",
			advanceType = "button",
			nextButtonText = "Далее",
			highlightPath = "GoldAccumulationGui.MainContainer.StoragePanel.ProgressContainer",
			arrowDirection = "down",
			watchVisiblePath = "GoldAccumulationGui.MainContainer",
    		rollbackStepId = "collect_gold"
		},
		{
			id = "collect_gold_3",
			message = "Нажмите на кнопку «Собрать», чтобы забрать накопленное золото.",
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
			message = "Здесь будут отображается купленные Вами диорамы, сколько золота они накопили.",
			advanceType = "button",
			nextButtonText = "Далее",
			highlightPath = "GoldAccumulationGui.MainContainer.DioramaList",
			arrowDirection = "down",
			messagePosition = "top",
			watchVisiblePath = "GoldAccumulationGui.MainContainer",
    		rollbackStepId = "collect_gold"

		},
		{
			id = "collect_gold_5",
			message = "Отлично! Теперь закройте окно, чтобы продолжить.",
    		advanceType = "gui_disabled",
    		guiName = "GoldAccumulationGui",
			highlightPath = "GoldAccumulationGui.MainContainer.Title.CloseButton",
			arrowDirection = "down",
		},
		{
			id = "open_hub",
			message = "Нажмите на кнопку в левой части экрана или на клавиатуре «Q», чтобы открыть хаб игры.",
			advanceType = "gui_enabled",
			guiName = "GameHubGui",
			highlightPath = "TopBar.LeftButtons.ManageButton",
			arrowDirection = "down",
		},
		{
			id = "level",
			message = "Здесь находится информация о твоем уровне и характеристиках",
			advanceType = "button",
			nextButtonText = "Далее",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.LevelCard",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "level_2",
			message = "Здесь находится информация о перерождении и его бонусы",
			advanceType = "button",
			nextButtonText = "Далее",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.RebirthCard",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "level_3",
			message = "Здесь находится информация о наградах за полученный уровень",
			advanceType = "button",
			nextButtonText = "Далее",
			highlightPath = "GameHubGui.MainContainer.ContentContainer.LevelPane.AwardCard",
			arrowDirection = "down",
			messagePosition = "top",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "upgrades",
			message = "Нажмите на кнопку чтобы открыть панль улучшения",
			advanceType = "gui_visible",
    		guiPath = "GameHubGui.MainContainer.ContentContainer.UpgradesPane",
			highlightPath = "GameHubGui.MainContainer.Header.TabsPanel.upgradesTab",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "upgrades_2",
			message = "Здесь вам предется улучшать свои характеристики",
			advanceType = "button",
			nextButtonText = "Далее",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests",
			message = "Нажмите на кнопку чтобы открыть панль квестов",
			advanceType = "gui_visible",
    		guiPath = "GameHubGui.MainContainer.ContentContainer.QuestsPane",
			highlightPath = "GameHubGui.MainContainer.Header.TabsPanel.questsTab",
			arrowDirection = "down",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests_2",
			message = "Выполняй задания чтобы получать золота и увеличивать уровнь",
			advanceType = "button",
			nextButtonText = "Далее",
			watchVisiblePath = "GameHubGui.MainContainer",
    		rollbackStepId = "open_hub"
		},
		{
			id = "quests_3",
			message = "Отлично! Теперь закройте окно, чтобы продолжить.",
    		advanceType = "gui_disabled",
    		guiName = "GameHubGui",
			highlightPath = "GameHubGui.MainContainer.Header.CloseButton",
			arrowDirection = "down",
		},
		{
			id = "go_to_diorama",
			message = "Подойдите к любому стенду диорамы и нажмите «E», чтобы открыть интерфейс покупки.",
			advanceType = "event",
			expectedEvent = "ShowDioramaGUI",
			eventFilter = function(dioramaId, data)
				return true
			end,
		},
		{
			id = "buy_diorama",
			message = "В этом меню доступна покупка диорамы за золото, а также за робуксы, если владелец выставил её на продазу за них.",
			advanceType = "button",
			nextButtonText = "Далее",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "buy_diorama_2",
			message = "Нажмите на кнопку чтобы открыть панль голосования",
			advanceType = "gui_visible",
    		guiPath = "PurchaseGui.MainFrame.Content.TabContent.Tab2Content.VotingSection",
			highlightPath = "PurchaseGui.MainFrame.TopBar.TabBar.TabButtons.Tab2",
			arrowDirection = "down",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "buy_diorama_3",
			message = "Голосуй за понравивщиеся диорамы и которые не нравятся, твой голос влияет на цену диорамы. Чем выше рейтинг, тем выше цена и наоборот.",
			advanceType = "button",
			nextButtonText = "Далее",
			watchVisiblePath = "PurchaseGui.MainFrame",
    		rollbackStepId = "go_to_diorama"
		},
		{
			id = "complete",
			message = "Обучение завершено! Теперь вы знаете основы.",
			advanceType = "button",
			nextButtonText = "Готово",
		},
	},
}