package com.example.lector.plugin;

import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Реестр возможностей, который плагины наполняют своими расширениями.
 * Ядро обращается только к реестру — оно не знает о конкретных плагинах.
 */
public class PluginRegistry {

    /** Фабрика блоков, регистрируемая плагином для кастомного типа. */
    public interface BlockFactory {
        ContentBlock create(long timestamp);

        /** Десериализация блока из JSON-представления, сохранённого ядром. */
        ContentBlock fromJson(JSONObject json, long timestamp);
    }

    /** Метаданные зарегистрированного типа блока. */
    public static class RegisteredType {
        public final String key;
        public final LectorPlugin owner;
        public final BlockFactory factory;

        RegisteredType(String key, LectorPlugin owner, BlockFactory factory) {
            this.key = key;
            this.owner = owner;
            this.factory = factory;
        }
    }

    private final Map<String, RegisteredType> blockTypes = new HashMap<>();
    private final List<BlockHandler> blockHandlers = new ArrayList<>();
    private final Map<String, FormattingCommand> formattingCommands = new HashMap<>();

    /** Регистрация нового типа блока плагином (аналог добавления предмета/блока в игру). */
    public void registerBlockType(String key, LectorPlugin owner, BlockFactory factory) {
        if (key == null || key.isEmpty()) return;
        blockTypes.put(key.toUpperCase(), new RegisteredType(key.toUpperCase(), owner, factory));
    }

    /** Создание блока кастомного типа по ключу; null если тип неизвестен. */
    public ContentBlock createBlock(String key, long timestamp) {
        RegisteredType rt = blockTypes.get(key.toUpperCase());
        return rt != null ? rt.factory.create(timestamp) : null;
    }

    /** Десериализация блока кастомного типа; null если тип неизвестен. */
    public ContentBlock deserializeBlock(String key, JSONObject json, long timestamp) {
        RegisteredType rt = blockTypes.get(key.toUpperCase());
        if (rt == null) return null;
        try {
            ContentBlock b = rt.factory.fromJson(json, timestamp);
            // Если factory не проставил таймкод из JSON — используем переданный
            if (b != null && b.getTimestamp() <= 0) b.setTimestamp(timestamp);
            return b;
        } catch (Exception e) {
            return null;
        }
    }

    public boolean isCustomType(String key) {
        return key != null && blockTypes.containsKey(key.toUpperCase());
    }

    public List<RegisteredType> getRegisteredTypes() {
        return new ArrayList<>(blockTypes.values());
    }

    /** Регистрация цепочки обработчиков текста. */
    public void registerBlockHandler(BlockHandler handler) {
        if (handler != null) blockHandlers.add(handler);
    }

    /** Опросить хендлеры плагинов; возвращает блок или null (тогда решает ядро). */
    public ContentBlock handleText(String text, long timestampMs) {
        for (BlockHandler h : blockHandlers) {
            try {
                if (h.canHandle(text, timestampMs)) {
                    ContentBlock b = h.createBlock(text, timestampMs);
                    if (b != null) return b;
                }
            } catch (Exception ignored) {
                // Сбой плагина не должен ломать транскрипцию
            }
        }
        return null;
    }

    public List<BlockHandler> getBlockHandlers() {
        return new ArrayList<>(blockHandlers);
    }

    /** Регистрация устной команды форматирования. */
    public void registerFormattingCommand(FormattingCommand command) {
        if (command != null && command.keyword() != null) {
            formattingCommands.put(command.keyword().toLowerCase(), command);
        }
    }

    /** Поиск команды по первому слову фразы. */
    public FormattingCommand findFormattingCommand(String phrase) {
        if (phrase == null) return null;
        String lower = phrase.trim().toLowerCase();
        int sp = lower.indexOf(' ');
        String firstWord = sp > 0 ? lower.substring(0, sp) : lower;
        return formattingCommands.get(firstWord);
    }

    public Map<String, FormattingCommand> getFormattingCommands() {
        return new HashMap<>(formattingCommands);
    }

    /** Все встроенные типы доступны плагинам как ориентир. */
    public static List<String> builtinTypeNames() {
        List<String> names = new ArrayList<>();
        for (BlockType t : BlockType.values()) names.add(t.name());
        return names;
    }
}
