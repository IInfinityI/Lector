# Руководство автора модов Lector

Lector спроектирован как голосовой блокнот с архитектурой «ядро + моды» (как моды в играх):
ядро обеспечивает запись, транскрипцию и хранение, а моды расширяют его, не изменяя код ядра.

## Архитектура API

Все интерфейсы находятся в пакете `com.example.lector.plugin`:

| Интерфейс | Назначение |
|---|---|
| `LectorPlugin` | Главный интерфейс мода: жизненный цикл и точка входа |
| `PluginRegistry` | Реестр: регистрация новых типов блоков и команд |
| `BlockHandler` | Цепочка ответственности: текст → блок контента |
| `FormattingCommand` | Обработчик устных команд («заголовок», «выделить») |
| `EventBus` | События ядра: RECORDING_STARTED / STOPPED, LECTURE_SAVED |
| `PostProcessor` | Пост-обработка готовой лекции после остановки записи (чистка, склейка, структура) |
| `BlockRenderer` | UI-слот: как мода-блок выглядит в редакторе и в Markdown-экспорте |
| `Exporter` / `ExportFormat` | Плагинный формат экспорта (PDF, DOCX, HTML...) — мода добавляет свой пункт в диалог «Экспорт» |
| `ToolbarAction` | UI-слот: кнопка мода на панели инструментов редактора (`getLabel`, `getOrder`, `isVisible`, `onClick(lecture, ctx)`) |
| `PluginContext` | Изолированное окружение мода (данные лекции, своя песочница на диске) |

Загрузкой и жизненным циклом модов управляет синглтон `PluginManager`.

## Как написать мод за 5 шагов

### 1. Реализуйте `LectorPlugin`

```java
public class MyMod implements LectorPlugin {
    @Override public String getId()    { return "org.example.mymod"; }
    @Override public String getName()  { return "Мой мод"; }
    @Override public String getDescription() { return "Что делает мод"; }

    @Override public void onInit(PluginContext ctx) {
        // Инициализация: ctx.getPluginDataDir() — изолированная папка мода
    }

    @Override public void onRegister(PluginRegistry registry) {
        // Регистрация типов блоков и команд (шаги 2–3)
    }
}
```

### 2. Добавьте новый тип блока

Расширьте `ContentBlock` (пример: `plugin/builtin/HighlightBlock.java`) и зарегистрируйте
тип в `onRegister`:

```java
registry.registerBlockType("highlight", this,
        timestamp -> new HighlightBlock("", timestamp));
```

Ядро умеет сериализовать/десериализовать произвольные блоки; неизвестные типы при
открытии старой лекции сохраняются как-is (обратная совместимость).

### 3. Научите мод создавать блок из речи (BlockHandler)

```java
@Override
public List<BlockHandler> getBlockHandlers() {
    return Collections.singletonList(new BlockHandler() {
        public String getName() { return "mymod.handler"; }
        public boolean canHandle(String text, long ts) {
            return text.startsWith("мой маркер");
        }
        public ContentBlock createBlock(String text, long ts) {
            return new HighlightBlock(text, ts);
        }
    });
}
```

Ядро опрашивает хендлеры модов **до** встроенного анализатора (цепочка ответственности).

### 4. Подпишитесь на события и добавьте пост-обработку

```java
@Override
public void subscribe(EventBus bus) {
    bus.subscribe(EventBus.Event.RECORDING_STOPPED,
            (event, payload) -> { /* ... */ });
}

@Override
public List<PostProcessor> getPostProcessors() {
    return Collections.singletonList(new PostProcessor() {
        @Override public String getName() { return "my-summary"; }
        @Override public void process(Lecture lecture) {
            // например: добавить блок «Краткое содержание» в конец конспекта
        }
    });
}
```

Ядро вызывает процессоры после встроенного `CorePostProcessor` (чистка повторов,
склейка абзацев, заголовок из названия предмета), перед сохранением лекции.
Исключение одного мода не ломает обработку остальных.

### 5. Подключите мод

Три способа загрузки (по возрастанию «внешности»):

1. **Встроенный мод** — класс внутри APK + строка в `assets/plugins.json`:
   ```json
   { "plugins": [ { "id": "org.example.mymod", "class": "org.example.mymod.MyMod" } ] }
   ```
2. **Gradle-модуль + ServiceLoader** — отдельный модуль с файлом
   `META-INF/services/com.example.lector.plugin.LectorPlugin`, содержащим имя класса.
3. **Динамическая загрузка DEX/JAR** — самый простой путь для пользователя:
   в разделе **«Моды»** нажмите «Импортировать мод» и выберите файл `.jar`/`.dex`.
   Файл копируется в `filesDir/plugins_ext/`, а при следующем запуске приложения
   загружается через `DexClassLoader`. Требования к архиву:
   - скомпилирован против API Lector (интерфейс `LectorPlugin` не должен меняться);
   - в корне архива (или в `assets/`) лежит манифест `plugin.json`:
     ```json
     { "id": "org.example.mymod", "class": "org.example.mymod.MyMod" }
     ```
   - класс из `class` имеет публичный конструктор без аргументов.

   Проверка совместимости: если мод запрашивает `getApiVersion()` выше, чем
   `PLUGIN_API_VERSION` ядра, он не будет загружен (ошибка видна в списке модов).

Моды можно включать/выключать в разделе **«Моды»** (PluginsFragment) — состояние
хранится в SharedPreferences.

## Пример: встроенный мод Highlighter

Смотрите `app/src/main/java/com/example/lector/plugin/builtin/HighlighterPlugin.java` —
полный минимальный рабочий пример: команда «выдели <текст>» превращает распознанный текст
в блок `HighlightBlock`, мод регистрирует UI-слот `BlockRenderer` (цветная подсветка
в редакторе + экспорт в виде GitHub-адмонации `> [!NOTE]`).

### UI-слоты (BlockRenderer)

По умолчанию кастомные блоки отображаются через `block.toMarkdown()`. Чтобы мод
управлял внешним видом своего блока в списке редактора и его Markdown-экспортом,
зарегистрируйте рендерер в `onRegister`:

```java
registry.registerBlockRenderer(MyBlock.TYPE_KEY, new BlockRenderer() {
    @Override
    public void render(ContentBlock block, TextView timestampView,
                       TextView contentView, View itemView) {
        contentView.setText(((MyBlock) block).getText());
        contentView.setBackgroundColor(myColor);
    }
    @Override
    public String renderMarkdown(ContentBlock block) {
        return "> " + ((MyBlock) block).getText();
    }
});
```

Ядро вызывает слоты с изоляцией ошибок: исключение в рендере мода не роняет
редактор и экспорт (происходит деградация на отрисовку ядра).

## Галерея встроенных модов

Все моды подключены декларативно через `assets/plugins.json` — код ядра их не знает,
ровно как аддоны в играх. Отключение: `"enabled": false` в JSON или тумблер на экране «Моды».

| Мод | ID | Что делает | Используемый API |
|-----|----|------------|-----------|
| Highlighter (демо) | `com.lector.highlighter` | Маркер `\=текст\=`, экспорт PDF, кнопка «Тег #» | BlockHandler, FormattingCommand, Exporter, ToolbarAction |
| TaskMaster | `com.lector.taskmaster` | Голосовые задачи «задача/не забыть/дз …» → чек-лист TODO; оранжевая карточка «☑ Задачи (N активных)»; склейка подряд продиктованных задач; GitHub-чекбоксы `- [x]` в Markdown; настраиваемый триггер | BlockHandler, BlockRenderer, PostProcessor, PluginSettings |
| SummaryBot | `com.lector.summarybot` | При остановке записи вставляет блок «✍ Резюме: …» (первые N предложений + счётчики «· формул · таблиц · задач»); кнопка «Резюме» пересобирает одним тапом; повторная обработка заменяет, а не дублирует; длина 1–10 предложений | BlockHandler, BlockRenderer, PostProcessor, ToolbarAction, PluginSettings |
| ObsidianVault | `com.lector.obsidianvault` | Экспорт лекции в хранилище Obsidian: Markdown с YAML-frontmatter (tags, date), авто-wiki-ссылки `[[...]]`, пересобираемый `_index.md`; голосовая команда «вики ссылка [тема]»; кнопка «Vault» в редакторе; хранилище в `files/obsidian-vault/` (Syncthing/Drive/git) | Exporter, BlockHandler, ToolbarAction, PluginSettings |
| SubjectPicker | `com.lector.subjectpicker` | Удобный старт лекции: дата подставляется автоматически, название предмета сохраняется в `SubjectRegistry` и предлагается при следующей лекции (автодополнение + список недавних) | EventBus, PluginSettings |

Пример подключения мода (`assets/plugins.json`):

```json
{
  "id": "com.lector.taskmaster",
  "class": "com.example.lector.plugin.builtin.TaskMasterPlugin",
  "enabled": true,
  "settings": { "trigger": "задача" }
}
```

Пример кода мода с настройкой (v1.4) — чтение пользовательского слова-триггера:

```java
@Override
public void onAttach(PluginContext ctx) {
    trigger = ctx.settings().getString("trigger", DEFAULT_TRIGGER);
    ctx.handlers().register("задача", (text, ts) -> newTodoBlock(text, ts));
    ctx.postProcessors().add(lecture -> mergeConsecutiveTodos(lecture));
}
```

## Соглашения и ограничения

* ID мода — обратно-доменный стиль, уникален; повторная регистрация игнорируется.
* Мод не должен хранить ссылки на UI-компоненты — только через `PluginContext`.
* Все исключения внутри мода перехватываются `PluginManager`: падение мода не роняет ядро.
* Версия API ядра — `getApiVersion()` (сейчас `1`); несовместимые моды отклоняются при загрузке.

## Дорожная карта API

* v1 (реализовано): типы блоков, BlockHandler, FormattingCommand, EventBus, PostProcessor.
* v1.1 (реализовано): UI-слоты BlockRenderer — кастомная отрисовка блоков мода в редакторе и Markdown-экспорте.
* v1.2 (реализовано): Exporter/ExportFormat — моды добавляют свои форматы экспорта (демо: PDF через системный PdfDocument в Highlighter).
* v1.3 (реализовано): ToolbarAction — плагинные кнопки на панели инструментов редактора (демо: «Тег #» в Highlighter). Ядро само наполняет контейнер тулбара; падение мода не ломает UI.
* v1.4 (реализовано): PluginSettings — настройки мода из `plugins.json` и с экрана «Моды» (триггер TaskMaster, длина резюме SummaryBot, папка/теги ObsidianVault).
* v1.5 (реализовано): EventBus-события жизненного цикла записи (RECORDING_STARTED/STOPPED) — моды реагируют на старт и остановку лекции.
* v2 (план): кастомные view-группы для рендеров (полноценный UI вместо стандартной ячейки).
* v3 (план): sandboxed-загрузка внешних APK-плагинов.

Следующие идеи модов: «Flashcards» (вопрос-ответ из определения), «Timestamp»
(команда «пометь» → закладка), экспорт DOCX отдельным модом.
