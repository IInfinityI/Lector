package com.example.lector.data;

import android.content.Context;
import android.content.SharedPreferences;

import com.example.lector.models.Lecture;

import org.json.JSONArray;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;

/**
 * Реестр предметов (API v1.5, UI-слот «предметы»).
 *
 * Хранит названия предметов, которые пользователь уже вводил при начале лекции.
 * Каждое имя сохраняется с датой последнего использования и счётчиком —
 * по ним список отдаётся в порядке «самые свежие/частые сверху», чтобы
 * экран начала записи мог показать готовые варианты одним тапом.
 *
 * Данные лежат в изолированном SharedPreferences "lector_subjects":
 *   {"v":1,"items":[{"name":"Высшая математика","lastUsed":...,"count":7}, ...]}
 */
public class SubjectRegistry {

    private static final String PREFS = "lector_subjects";
    private static final String KEY = "items";

    /**
     * Модификатор строки чипа: «Математика · 12 лекций» / «Математика · сегодня».
     */
    public static class ChipDecorator {
        public String decorate(String name, int lectureCount) {
            if (lectureCount <= 0) return name;
            String suffix;
            if (lectureCount == 1) suffix = "1 лекция";
            else if (lectureCount < 5) suffix = lectureCount + " лекции";
            else suffix = lectureCount + " лекций";
            return name + " · " + suffix;
        }
    }

    /** Одна запись реестра: название + метаданные для сортировки. */
    public static class Entry {
        public final String name;
        public final long lastUsed;
        public final int count;

        public Entry(String name, long lastUsed, int count) {
            this.name = name;
            this.lastUsed = lastUsed;
            this.count = count;
        }
    }

    private final SharedPreferences prefs;

    public SubjectRegistry(Context context) {
        this.prefs = context.getApplicationContext()
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /**
     * Запомнить предмет (вызывается при старте записи и при сохранении лекции).
     * Пустые имена игнорируются; повторное использование поднимает запись наверх.
     */
    public void remember(String rawName) {
        String name = normalize(rawName);
        if (name.isEmpty()) return;

        Map<String, Entry> items = readItems();
        Entry old = findByLower(items, name.toLowerCase(Locale.ROOT));
        int count = old != null ? old.count + 1 : 1;
        if (old != null) items.remove(old.name);
        items.put(name, new Entry(name, System.currentTimeMillis(), count));
        writeItems(items);
    }

    /** Все известные предметы: сначала последние использованные. */
    public List<Entry> recent(int limit) {
        List<Entry> list = new ArrayList<>(readItems().values());
        Collections.sort(list, new Comparator<Entry>() {
            @Override
            public int compare(Entry a, Entry b) {
                if (a.lastUsed != b.lastUsed) return Long.compare(b.lastUsed, a.lastUsed);
                return a.name.compareToIgnoreCase(b.name);
            }
        });
        if (limit > 0 && list.size() > limit) return new ArrayList<>(list.subList(0, limit));
        return list;
    }

    public boolean isEmpty() {
        return readItems().isEmpty();
    }

    /**
     * Сколько лекций записано по каждому предмету (название → количество).
     * Считается по JSON-хранилищу; ошибки на отдельном файле игнорируются.
     */
    public java.util.Map<String, Integer> subjectStats(android.content.Context app) {
        java.util.Map<String, Integer> stats =
            new java.util.TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        try {
            List<Lecture> all = new LectureRepository(app).loadAll();
            for (Lecture l : all) {
                String name = normalize(l.getSubjectSafe());
                if (!name.isEmpty()) stats.merge(name, 1, Integer::sum);
            }
        } catch (Exception ignored) { }
        return stats;
    }

    public void forget(String rawName) {
        String key = normalize(rawName).toLowerCase(Locale.ROOT);
        Map<String, Entry> items = readItems();
        Entry e = findByLower(items, key);
        if (e != null) {
            items.remove(e.name);
            writeItems(items);
        }
    }

    // ===== утилиты =====

    /** Название для отображения: без лишних пробелов/кавычек. */
    public static String normalize(String raw) {
        if (raw == null) return "";
        return raw.trim().replaceAll("\\s+", " ");
    }

    /** Имя файла из названия предмета и даты: «Математика_2026-10-10.md». */
    public static String fileTitle(String subject, long dateMs) {
        String s = normalize(subject);
        s = s.replaceAll("[\\\\/:*?\"<>|#\\[\\]^]", "").trim().replaceAll("\\s+", "-");
        if (s.isEmpty()) s = "Лекция";
        String d = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(new java.util.Date(dateMs));
        return s + "_" + d;
    }

    private static Entry findByLower(Map<String, Entry> items, String lowerKey) {
        for (Entry e : items.values()) {
            if (e.name.toLowerCase(Locale.ROOT).equals(lowerKey)) return e;
        }
        return null;
    }

    private Map<String, Entry> readItems() {
        Map<String, Entry> result = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        try {
            JSONArray arr = new JSONArray(prefs.getString(KEY, "[]"));
            for (int i = 0; i < arr.length(); i++) {
                org.json.JSONObject o = arr.optJSONObject(i);
                if (o == null) continue;
                String name = normalize(o.optString("name", ""));
                if (name.isEmpty()) continue;
                result.put(name, new Entry(name,
                    o.optLong("lastUsed", 0), o.optInt("count", 1)));
            }
        } catch (Exception ignored) { }
        return result;
    }

    private void writeItems(Map<String, Entry> items) {
        try {
            JSONArray arr = new JSONArray();
            for (Entry e : items.values()) {
                org.json.JSONObject o = new org.json.JSONObject();
                o.put("name", e.name);
                o.put("lastUsed", e.lastUsed);
                o.put("count", e.count);
                arr.put(o);
            }
            prefs.edit().putString(KEY, arr.toString()).apply();
        } catch (Exception ignored) { }
    }
}
