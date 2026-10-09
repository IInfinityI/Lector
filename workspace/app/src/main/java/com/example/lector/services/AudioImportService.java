package com.example.lector.services;

import android.content.Context;
import android.database.Cursor;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;

import com.example.lector.data.LectureRepository;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.plugin.PluginManager;
import com.example.lector.plugin.PluginRegistry;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Импорт и транскрибирование готовых аудиофайлов (записанных лекций, подкастов).
 *
 * Файл копируется во внутреннее хранилище, после чего запускается офлайн-распознавание
 * Android SpeechRecognizer по предварительно извлечённым фрагментам PCM
 * (см. TranscriptionService.transcribeFile). Результат сохраняется как обычная
 * Lecture — дальше с ней работают редактор, пост-обработка и моды (экспорт, рендереры).
 */
public class AudioImportService {

    private static final String TAG = "AudioImportService";

    public interface Callback {
        /** progress в долях 0..1, description — текст для UI. */
        void onProgress(float progress, String description);
        void onFinished(Lecture lecture);
        void onError(String message);
    }

    private final Context context;
    private final java.util.concurrent.ExecutorService executor =
        java.util.concurrent.Executors.newSingleThreadExecutor();

    public AudioImportService(Context context) {
        this.context = context.getApplicationContext();
    }

    /** Импортирует audio-файл из SAF (ACTION_OPEN_DOCUMENT) и запускает транскрибирование. */
    public void importAndTranscribe(Uri uri, String subjectHint, Callback callback) {
        executor.execute(() -> {
            try {
                // 1. Копируем файл во внутреннее хранилище
                callbackOn(callback, 0.05f, "Копирование файла...");
                String displayName = queryDisplayName(uri);
                if (displayName == null || displayName.isEmpty()) displayName = "imported.m4a";
                File dest = new File(context.getFilesDir(), "audio/" + System.currentTimeMillis() + "_" + displayName);
                dest.getParentFile().mkdirs();
                copyUriToFile(uri, dest);

                // 2. Длительность
                long durationMs = readDurationMs(dest);
                callbackOn(callback, 0.15f, "Подготовка к распознаванию...");

                // 3. Транскрибирование (офлайн SpeechRecognizer по фрагментам)
                List<String> phrases = TranscriptionService.transcribeFile(
                    context, dest.getAbsolutePath(),
                    p -> callbackOn(callback, 0.15f + p * 0.75f, "Распознавание речи..."));

                // 4. Сборка лекции через пайплайн ядра + модов
                callbackOn(callback, 0.92f, "Пост-обработка...");
                String subject = (subjectHint != null && !subjectHint.trim().isEmpty())
                    ? subjectHint.trim()
                    : displayName.replaceFirst("\\.[^.]+$", "");
                Lecture lecture = buildLecture(subject, dest.getAbsolutePath(), durationMs, phrases);

                new CorePostProcessor().process(lecture);
                PluginRegistry registry = PluginManager.getInstance(context).getRegistry();
                registry.runPostProcessors(lecture);

                boolean saved = new LectureRepository(context).save(lecture);
                if (!saved) {
                    callback.onError("Не удалось сохранить распознанную лекцию");
                    return;
                }
                callbackOn(callback, 1.0f, "Готово");
                callback.onFinished(lecture);
            } catch (Exception e) {
                Log.e(TAG, "import failed", e);
                callback.onError("Ошибка импорта: " + e.getMessage());
            }
        });
    }

    private Lecture buildLecture(String subject, String audioPath, long durationMs, List<String> phrases) {
        ContentAnalyzerService analyzer = new ContentAnalyzerService();
        Lecture lecture = new Lecture(subject, System.currentTimeMillis());
        lecture.setAudioPath(audioPath);
        lecture.setDuration(durationMs);

        List<com.example.lector.models.ContentBlock> blocks = new ArrayList<>();
        long ts = 0;
        for (String phrase : phrases) {
            if (phrase == null || phrase.trim().isEmpty()) continue;
            com.example.lector.models.ContentBlock b = null;
            // Моды имеют приоритет над ядром — тот же порядок, что при живой записи
            try {
                b = PluginManager.getInstance(context).getRegistry()
                    .handleText(phrase, ts);
            } catch (Exception ignored) {}
            if (b == null) b = analyzer.analyzeText(phrase, ts);
            if (b instanceof TextBlock) ((TextBlock) b).setSpeakerName("Преподаватель");
            blocks.add(b);
            ts += Math.max(2000, durationMs / Math.max(1, phrases.size()));
        }
        lecture.setBlocks(blocks);
        return lecture;
    }

    private long readDurationMs(File f) {
        try (MediaMetadataRetriever r = new MediaMetadataRetriever()) {
            r.setDataSource(f.getAbsolutePath());
            String d = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            return d != null ? Long.parseLong(d) : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private String queryDisplayName(Uri uri) {
        try (Cursor c = context.getContentResolver().query(uri, null, null, null, null)) {
            if (c != null && c.moveToFirst()) {
                int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) return c.getString(idx);
            }
        } catch (Exception ignored) {}
        return null;
    }

    private void copyUriToFile(Uri uri, File dest) throws Exception {
        try (InputStream in = context.getContentResolver().openInputStream(uri);
             OutputStream out = new FileOutputStream(dest)) {
            if (in == null) throw new IllegalStateException("Не удалось открыть файл");
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }

    private void callbackOn(Callback cb, float p, String s) {
        // Прогресс может обновлять UI — отправляем в главный поток
        new android.os.Handler(context.getMainLooper()).post(() -> cb.onProgress(p, s));
    }
}
