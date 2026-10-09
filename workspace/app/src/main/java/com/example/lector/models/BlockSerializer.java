package com.example.lector.models;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Контракт сериализации блоков контента в JSON.
 * Любая реализация ContentBlock (встроенная или плагинная) обязана уметь:
 *  - {@link #toJson()} — сохранить своё состояние;
 *  - восстановить себя через статический метод fromJson своего класса.
 */
public interface BlockSerializer {
    JSONObject toJson();

    /** Произвольные данные блока (без служебных полей id/timestamp). */
    static JSONArray listToJson(Iterable<? extends ContentBlock> blocks) {
        JSONArray arr = new JSONArray();
        for (ContentBlock b : blocks) {
            if (b instanceof BlockSerializer) {
                try {
                    arr.put(((BlockSerializer) b).toJson());
                } catch (Exception ignored) {
                }
            }
        }
        return arr;
    }
}
