package com.example.lector.plugin.builtin;

import com.example.lector.models.BlockSerializer;
import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Кастомный блок мода «TaskMaster» — чек-лист задач, продиктованных голосом.
 *
 * Тип блока для JSON/реестра: {@code TODO} (ядро его не знает — весь цикл
 * жизни блока принадлежит моду через Plugin API v1.0–v1.4).
 * Статус выполнения каждого пункта сохраняется в JSON (☐/☑).
 */
public class TodoBlock extends ContentBlock implements BlockSerializer {

    public static final String TYPE_KEY = "TODO";

    private final List<TodoItem> items = new ArrayList<>();

    public TodoBlock(long timestamp) {
        super(timestamp);
    }

    @Override
    public BlockType getType() {
        return BlockType.TEXT; // базовый fallback для старого UI
    }

    @Override
    public String getTypeKey() {
        return TYPE_KEY; // реальный тип для JSON и реестра рендереров
    }

    public List<TodoItem> getItems() { return items; }

    public void addItem(TodoItem item) {
        if (item != null && !item.getText().isEmpty()) items.add(item);
    }

    public boolean addIfTodo(String text) {
        String t = TaskMasterPlugin.stripTrigger(text, null);
        if (t == null || t.isEmpty()) return false;
        addItem(new TodoItem(t));
        return true;
    }

    /** Переключить выполнено/не выполнено по индексу (тап по пункту в редакторе). */
    public void toggle(int index) {
        if (index >= 0 && index < items.size()) items.get(index).toggle();
    }

    public int activeCount() {
        int n = 0;
        for (TodoItem i : items) if (!i.isDone()) n++;
        return n;
    }

    public boolean mergeFrom(TodoBlock other) {
        if (other == null) return false;
        for (TodoItem i : other.items) addItem(i);
        return true;
    }

    @Override
    public JSONObject toJson() {
        JSONObject json = super.toJson(); // служебные поля + type=TODO из getTypeKey()
        try {
            json.put("items", TodoItem.arrayToJson(items));
        } catch (Exception ignored) { }
        return json;
    }

    public static TodoBlock fromJson(JSONObject json, long timestamp) {
        TodoBlock b = new TodoBlock(timestamp);
        JSONArray arr = json.optJSONArray("items");
        if (arr != null) {
            for (int i = 0; i < arr.length(); i++) {
                TodoItem item = TodoItem.fromJson(arr.optJSONObject(i));
                if (item != null) b.addItem(item);
            }
        }
        String savedId = json.optString("id", null);
        if (savedId != null) b.id = savedId;
        b.applyBaseJson(json);
        return b;
    }

    /** Markdown GitHub-чекбоксов: - [x] / - [ ] (тот же формат, что и в рендерере). */
    @Override
    public String toMarkdown() {
        StringBuilder sb = new StringBuilder();
        for (TodoItem i : items) {
            sb.append(i.isDone() ? "- [x] " : "- [ ] ").append(i.getText()).append("\n");
        }
        return sb.toString().trim();
    }
}
