package com.example.lector.data;

import android.content.Context;
import android.util.Log;

import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.ParagraphBlock;
import com.example.lector.models.Speaker;
import com.example.lector.plugin.PluginManager;
import com.example.lector.plugin.PluginRegistry;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * Хранилище лекций: JSON-файлы в filesDir/lectures/<id>.json.
 * Формат расширяемый — блоки кастомных типов десериализуются через
 * PluginRegistry, поэтому моды могут добавлять свои типы без миграции схемы.
 */
public class LectureRepository {

    private static final String TAG = "LectureRepository";
    public static final int SCHEMA_VERSION = 1;

    private final File storageDir;
    private final PluginRegistry registry;

    public LectureRepository(Context context) {
        this.storageDir = new File(context.getFilesDir(), "lectures");
        if (!storageDir.exists()) storageDir.mkdirs();
        this.registry = PluginManager.getInstance(context).getRegistry();
    }

    // ===== CRUD =====

    public boolean save(Lecture lecture) {
        try {
            JSONObject json = lectureToJson(lecture);
            File f = fileFor(lecture.getId());
            try (OutputStreamWriter w = new OutputStreamWriter(
                    new FileOutputStream(f), "UTF-8")) {
                w.write(json.toString(2));
            }
            return true;
        } catch (Exception e) {
            Log.e(TAG, "save failed", e);
            return false;
        }
    }

    public Lecture load(String id) {
        File f = fileFor(id);
        if (!f.exists()) return null;
        try {
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(
                    new FileInputStream(f), "UTF-8"))) {
                String line;
                while ((line = r.readLine()) != null) sb.append(line);
            }
            return lectureFromJson(new JSONObject(sb.toString()));
        } catch (Exception e) {
            Log.e(TAG, "load failed for " + id, e);
            return null;
        }
    }

    public boolean delete(String id) {
        Lecture l = load(id);
        boolean ok = fileFor(id).delete();
        if (ok && l != null && l.getAudioPath() != null) {
            File audio = new File(l.getAudioPath());
            if (audio.exists()) audio.delete();
        }
        return ok;
    }

    /** Все лекции, отсортированные по дате (новые сверху). */
    public List<Lecture> loadAll() {
        List<Lecture> result = new ArrayList<>();
        File[] files = storageDir.listFiles((dir, name) -> name.endsWith(".json"));
        if (files == null) return result;
        Arrays.sort(files, Comparator.comparingLong(File::lastModified));
        for (File f : files) {
            try {
                Lecture l = load(f.getName().replace(".json", ""));
                if (l != null) result.add(l);
            } catch (Exception ignored) {}
        }
        java.util.Collections.reverse(result);
        return result;
    }

    // ===== Сериализация =====

    private JSONObject lectureToJson(Lecture lecture) throws Exception {
        JSONObject json = new JSONObject();
        json.put("schemaVersion", SCHEMA_VERSION);
        json.put("id", lecture.getId());
        json.put("subject", lecture.getSubject());
        json.put("date", lecture.getDate());
        json.put("audioPath", lecture.getAudioPath());
        json.put("duration", lecture.getDuration());
        json.put("isVerified", lecture.isVerified());
        json.put("notes", lecture.getNotes());

        JSONArray speakers = new JSONArray();
        for (Speaker sp : lecture.getSpeakers()) {
            JSONObject o = new JSONObject();
            o.put("id", sp.getId());
            o.put("name", sp.getName());
            o.put("color", sp.getColor());
            o.put("totalSpeakingTime", sp.getTotalSpeakingTime());
            speakers.put(o);
        }
        json.put("speakers", speakers);

        JSONArray blocks = new JSONArray();
        for (ContentBlock b : lecture.getBlocks()) {
            JSONObject bo = blockToJson(b);
            if (bo != null) blocks.put(bo);
        }
        json.put("blocks", blocks);
        return json;
    }

    private JSONObject blockToJson(ContentBlock b) {
        try {
            if (!(b instanceof com.example.lector.models.BlockSerializer)) return null;
            return ((com.example.lector.models.BlockSerializer) b).toJson();
        } catch (Exception e) {
            Log.w(TAG, "block serialize failed: " + b.getTypeKey(), e);
            return null;
        }
    }

    private Lecture lectureFromJson(JSONObject json) {
        Lecture lecture = new Lecture(json.optString("subject", "Лекция"),
            json.optLong("date", System.currentTimeMillis()));
        String savedId = json.optString("id", null);
        if (savedId != null) lecture.setId(savedId);

        lecture.setAudioPath(json.optString("audioPath", null));
        lecture.setDuration(json.optLong("duration", 0));
        lecture.setVerified(json.optBoolean("isVerified", false));
        lecture.setNotes(json.optString("notes", null));

        JSONArray speakers = json.optJSONArray("speakers");
        if (speakers != null) {
            List<Speaker> list = new ArrayList<>();
            for (int i = 0; i < speakers.length(); i++) {
                JSONObject o = speakers.optJSONObject(i);
                if (o == null) continue;
                Speaker sp = new Speaker(o.optInt("id", i), o.optString("name", "Спикер"));
                sp.setColor(o.optInt("color", sp.getColor()));
                sp.setTotalSpeakingTime(o.optInt("totalSpeakingTime", 0));
                list.add(sp);
            }
            if (!list.isEmpty()) lecture.setSpeakers(list);
        }

        JSONArray blocks = json.optJSONArray("blocks");
        if (blocks != null) {
            for (int i = 0; i < blocks.length(); i++) {
                JSONObject bo = blocks.optJSONObject(i);
                if (bo == null) continue;
                ContentBlock b = blockFromJson(bo);
                if (b != null) lecture.addBlock(b);
            }
        }
        return lecture;
    }

    /**
     * Десериализация блока: сначала встроенные типы, затем кастомные из реестра.
     * Неизвестный тип (например, плагин удалён) молча пропускается —
     * файл остаётся читаемым, это контракт обратной совместимости модов.
     */
    private ContentBlock blockFromJson(JSONObject json) {
        String type = json.optString("type", "");
        long ts = json.optLong("timestamp", 0);
        try {
            switch (type) {
                case "TEXT":      return com.example.lector.models.TextBlock.fromJson(json, ts);
                case "MATH":      return com.example.lector.models.MathBlock.fromJson(json, ts);
                case "TABLE":     return com.example.lector.models.TableBlock.fromJson(json, ts);
                case "IMAGE":     return com.example.lector.models.ImageBlock.fromJson(json, ts);
                case "GRAPH":     return com.example.lector.models.GraphBlock.fromJson(json, ts);
                case "HEADING":
                case "SUBHEADING":return com.example.lector.models.HeadingBlock.fromJson(json, ts);
                case "PARAGRAPH": return ParagraphBlock.fromJson(json, ts);
                default:
                    return registry.deserializeBlock(type, json, ts);
            }
        } catch (Exception e) {
            Log.w(TAG, "Unknown/skipped block type: " + type);
            return null;
        }
    }

    private File fileFor(String id) {
        return new File(storageDir, id + ".json");
    }
}
