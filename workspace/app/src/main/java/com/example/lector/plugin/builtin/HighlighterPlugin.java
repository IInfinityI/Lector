package com.example.lector.plugin.builtin;

import com.example.lector.plugin.BlockHandler;
import com.example.lector.plugin.EventBus;
import com.example.lector.plugin.LectorPlugin;
import com.example.lector.plugin.PluginContext;
import com.example.lector.plugin.PluginRegistry;

/**
 * Демо-мод «Highlighter»: распознаёт устные команды
 *  - «ключевое …» / «выдели …» / «определение …»
 * и превращает фразу в блок HighlightBlock (кастомный тип HIGHLIGHT).
 *
 * Плагин подключается списком в assets/plugins.json — без правки ядра.
 */
public class HighlighterPlugin implements LectorPlugin {

    public static final String ID = "builtin.highlighter";

    @Override
    public String getId() { return ID; }

    @Override
    public String getName() { return "Highlighter"; }

    @Override
    public String getDescription() {
        return "Выделение ключевых мыслей и определений цветными блоками.";
    }

    @Override
    public void onInit(PluginContext context) { /* демо: настройки не требуются */ }

    @Override
    public void onRegister(PluginRegistry registry) {
        // 1. Новый тип блока
        registry.registerBlockType(HighlightBlock.TYPE_KEY, this,
            new PluginRegistry.BlockFactory() {
                @Override
                public com.example.lector.models.ContentBlock create(long timestamp) {
                    return new HighlightBlock("", timestamp);
                }

                @Override
                public com.example.lector.models.ContentBlock fromJson(org.json.JSONObject json,
                                                                       long timestamp) {
                    return HighlightBlock.fromJson(json, timestamp);
                }
            });

        // 2. Обработчик текста: фразы с триггерными словами → HighlightBlock
        registry.registerBlockHandler(new BlockHandler() {
            @Override
            public String getName() { return "highlight-keywords"; }

            @Override
            public boolean canHandle(String text, long timestampMs) {
                if (text == null) return false;
                String lower = text.toLowerCase();
                return lower.startsWith("ключевое") || lower.startsWith("выдели")
                    || lower.startsWith("определение");
            }

            @Override
            public com.example.lector.models.ContentBlock createBlock(String text, long timestampMs) {
                String lower = text.toLowerCase();
                String color = lower.startsWith("определение") ? "blue" : "yellow";
                // Убираем триггерное слово из содержимого
                int sp = text.indexOf(' ');
                String body = sp > 0 ? text.substring(sp + 1) : text;
                return new HighlightBlock(body, timestampMs, color);
            }
        });
    }

    @Override
    public void subscribe(EventBus bus) {
        // Демо: можно вести статистику выделений в свою песочницу
    }
}
