package com.example.lector.plugin;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import com.example.lector.models.ContentBlock;
import com.example.lector.plugin.builtin.HighlightBlock;
import com.example.lector.plugin.builtin.HighlighterPlugin;

import org.json.JSONObject;
import org.junit.Test;

/**
 * Тесты Plugin API — гарантируют стабильность контракта «ядро + моды»:
 * реестр типов блоков, цепочка BlockHandler и EventBus работают как документировано.
 */
public class PluginRegistryTest {

    private LectorPlugin dummyPlugin(final String id) {
        return new LectorPlugin() {
            @Override public String getId() { return id; }
            @Override public String getName() { return id; }
            @Override public String getDescription() { return ""; }
            @Override public void onInit(PluginContext context) { }
            @Override public void onRegister(PluginRegistry registry) { }
        };
    }

    @Test
    public void registerBlockType_createAndDeserialize() {
        PluginRegistry registry = new PluginRegistry();
        LectorPlugin owner = dummyPlugin("test.mod");
        registry.registerBlockType("marker", owner, new PluginRegistry.BlockFactory() {
            @Override public ContentBlock create(long timestamp) {
                return new HighlightBlock("new", timestamp);
            }
            @Override public ContentBlock fromJson(JSONObject json, long timestamp) {
                return HighlightBlock.fromJson(json, timestamp);
            }
        });

        assertTrue(registry.isCustomType("MARKER"));
        assertFalse(registry.isCustomType("UNKNOWN"));

        ContentBlock created = registry.createBlock("marker", 123L);
        assertNotNull(created);
        assertTrue(created instanceof HighlightBlock);
        assertEquals(123L, created.getTimestamp());

        JSONObject json = new JSONObject();
        try {
            json.put("text", "сохранённый маркер");
            json.put("color", "blue");
        } catch (Exception ignored) { }
        ContentBlock restored = registry.deserializeBlock("MARKER", json, 456L);
        assertNotNull(restored);
        assertEquals("сохранённый маркер", ((HighlightBlock) restored).getText());
        assertEquals("blue", ((HighlightBlock) restored).getColor());
    }

    @Test
    public void unknownType_returnsNull_backwardCompatible() {
        PluginRegistry registry = new PluginRegistry();
        assertNull(registry.createBlock("GHOST", 1L));
        assertNull(registry.deserializeBlock("GHOST", new JSONObject(), 1L));
    }

    @Test
    public void blockHandlers_chainOfResponsibility_firstWins() {
        PluginRegistry registry = new PluginRegistry();

        registry.registerBlockHandler(new BlockHandler() {
            @Override public String getName() { return "first"; }
            @Override public boolean canHandle(String text, long ts) {
                return text != null && text.startsWith("один");
            }
            @Override public ContentBlock createBlock(String text, long ts) {
                return new HighlightBlock("from-first", ts);
            }
        });
        registry.registerBlockHandler(new BlockHandler() {
            @Override public String getName() { return "second"; }
            @Override public boolean canHandle(String text, long ts) {
                return text != null && text.startsWith("два");
            }
            @Override public ContentBlock createBlock(String text, long ts) {
                return new HighlightBlock("from-second", ts);
            }
        });

        ContentBlock a = registry.handleText("один два", 10L);
        assertNotNull(a);
        assertEquals("from-first", ((HighlightBlock) a).getText());

        ContentBlock b = registry.handleText("два", 20L);
        assertNotNull(b);
        assertEquals("from-second", ((HighlightBlock) b).getText());

        assertNull(registry.handleText("ничего не совпало", 30L));
    }

    @Test
    public void eventBus_publishReachesSubscriber() {
        EventBus bus = new EventBus();
        final int[] hits = {0};
        final Object[] lastPayload = {null};

        bus.subscribe(EventBus.Event.RECORDING_STARTED, (event, payload) -> {
            hits[0]++;
            lastPayload[0] = payload;
        });

        bus.publish(EventBus.Event.RECORDING_STARTED, "lecture-1");
        assertEquals(1, hits[0]);
        assertEquals("lecture-1", lastPayload[0]);

        // Другое событие не должно трогать подписчика
        bus.publish(EventBus.Event.LECTURE_SAVED, "x");
        assertEquals(1, hits[0]);
    }

    @Test
    public void highlighterPlugin_endToEnd() {
        // Мод из plugins.json реально регистрирует тип и хендлер в пустой реестр
        PluginRegistry registry = new PluginRegistry();
        HighlighterPlugin mod = new HighlighterPlugin();
        mod.onRegister(registry);

        assertTrue(registry.isCustomType(HighlightBlock.TYPE_KEY));
        ContentBlock block = registry.handleText("выдели главное уравнение лекции", 99L);
        assertNotNull("Хендлер мода должен создать блок", block);
        assertEquals(HighlightBlock.TYPE_KEY, block.getTypeKey());
        assertTrue(block.toMarkdown().contains("**"));

        // UI-слот мода: экспорт через реестр использует BlockRenderer плагина
        assertNotNull("Мод должен зарегистрировать BlockRenderer",
            registry.getRenderer(HighlightBlock.TYPE_KEY));
        String md = registry.exportBlockMarkdown(block);
        assertTrue("renderMarkdown мода добавляет GitHub-адмонیشن",
            md.startsWith("> [!NOTE]"));
    }

    @Test
    public void blockRendererSlot_customModOwnsItsRendering() {
        // Сторонний мод регистрирует свой тип + рендерер — ядро делегирует ему
        PluginRegistry registry = new PluginRegistry();
        LectorPlugin owner = dummyPlugin("test.renderer");
        registry.registerBlockType("CODE", owner, new PluginRegistry.BlockFactory() {
            @Override public ContentBlock create(long timestamp) { return null; }
            @Override public ContentBlock fromJson(JSONObject json, long ts) { return null; }
        });
        assertNull(registry.getRenderer("CODE")); // до регистрации слота — отрисовка ядра

        registry.registerBlockRenderer("CODE", new BlockRenderer() {
            @Override
            public void render(ContentBlock b, android.widget.TextView ts,
                               android.widget.TextView c, android.view.View v) { }
            @Override
            public String renderMarkdown(ContentBlock b) { return "```custom```"; }
        });
        assertEquals("```custom```", registry.getRenderer("code").renderMarkdown(null));
        // Экспорт неизвестного/безопасного блока падает на toMarkdown ядра без исключения
        assertEquals("", registry.exportBlockMarkdown(null));
    }
}
