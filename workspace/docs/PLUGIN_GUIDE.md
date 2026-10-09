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

### 4. Подпишитесь на события

```java
@Override
public void subscribe(EventBus bus) {
    bus.subscribe(EventBus.Event.RECORDING_STOPPED,
            (event, payload) -> { /* ... */ });
}
```

### 5. Подключите мод

Три способа загрузки (по возрастанию «внешности»):

1. **Встроенный мод** — класс внутри APK + строка в `assets/plugins.json`:
   ```json
   { "plugins": [ { "id": "org.example.mymod", "class": "org.example.mymod.MyMod" } ] }
   ```
2. **Gradle-модуль + ServiceLoader** — отдельный модуль с файлом
   `META-INF/services/com.example.lector.plugin.LectorPlugin`, содержащим имя класса.
3. **Динамическая загрузка DEX/JAR** — файл кладётся в `filesDir/plugins_ext/`,
   загружается через `DexClassLoader` (предусмотрено в `PluginManager`).

Моды можно включать/выключать в разделе **«Моды»** (PluginsFragment) — состояние
хранится в SharedPreferences.

## Пример: встроенный мод Highlighter

Смотрите `app/src/main/java/com/example/lector/plugin/builtin/HighlighterPlugin.java` —
полный минимальный рабочий пример: команда «выдели <текст>» превращает распознанный текст
в блок `HighlightBlock` с экспортом в Markdown (`==текст==`).

## Соглашения и ограничения

* ID мода — обратно-доменный стиль, уникален; повторная регистрация игнорируется.
* Мод не должен хранить ссылки на UI-компоненты — только через `PluginContext`.
* Все исключения внутри мода перехватываются `PluginManager`: падение мода не роняет ядро.
* Версия API ядра — `getApiVersion()` (сейчас `1`); несовместимые моды отклоняются при загрузке.

## Дорожная карта API

* v1 (реализовано): типы блоков, BlockHandler, FormattingCommand, EventBus.
* v2 (план): экспорт-фильтры (hook в Markdown/PDF-экспорт), UI-слоты в редакторе.
* v3 (план): sandboxed-загрузка внешних APK-плагинов.
