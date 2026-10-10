package com.example.lector.plugin.builtin;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Один пункт чек-листа мода «TaskMaster».
 * Сохраняется внутри TodoBlock в JSON вместе со статусом выполнения (v1.0).
 */
public class TodoItem {

    private String text;
    private boolean done;

    public TodoItem(String text) {
        this(text, false);
    }

    public TodoItem(String text, boolean done) {
        this.text = text == null ? "" : text.trim();
        this.done = done;
    }

    public String getText() { return text; }
    public void setText(String text) { this.text = text == null ? "" : text.trim(); }
    public boolean isDone() { return done; }
    public void setDone(boolean done) { this.done = done; }
    public void toggle() { this.done = !this.done; }

    JSONObject toJson() {
        JSONObject o = new JSONObject();
        try {
            o.put("text", text);
            o.put("done", done);
        } catch (Exception ignored) { }
        return o;
    }

    static TodoItem fromJson(JSONObject o) {
        if (o == null) return null;
        String t = o.optString("text", "").trim();
        if (t.isEmpty()) return null;
        return new TodoItem(t, o.optBoolean("done", false));
    }

    /** Массив пунктов → JSON-массив (для TodoBlock.toJson). */
    static JSONArray arrayToJson(Iterable<TodoItem> items) {
        JSONArray arr = new JSONArray();
        for (TodoItem i : items) arr.put(i.toJson());
        return arr;
    }
}
