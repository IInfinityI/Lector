package com.example.lector.services;

import android.content.Context;
import android.media.MediaRecorder;
import android.os.Build;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Сервис для записи аудио в формате M4A (AAC).
 * Работает полностью офлайн, сохраняет файлы локально.
 */
public class AudioRecorderService {
    private static final String TAG = "AudioRecorderService";
    
    private Context context;
    private MediaRecorder mediaRecorder;
    private String currentOutputPath;
    private long startTime;
    private boolean isRecording = false;
    private RecordingListener listener;

    public AudioRecorderService(Context context) {
        this.context = context.getApplicationContext();
    }

    /**
     * Начать запись
     * @param subject Название предмета (для имени файла)
     */
    public void startRecording(String subject) throws IOException {
        if (isRecording) {
            throw new IllegalStateException("Запись уже идет");
        }

        // Создаем директорию для записей
        File recordingsDir = new File(context.getExternalFilesDir(null), "recordings");
        if (!recordingsDir.exists()) {
            recordingsDir.mkdirs();
        }

        // Генерируем имя файла: Предмет_Дата_Время.m4a
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault());
        String dateStr = sdf.format(new Date());
        String safeSubject = subject.replaceAll("[^a-zA-Z0-9а-яА-ЯёЁ\\s_-]", "")
                .trim()
                .replaceAll("\\s+", "_");
        String fileName = safeSubject + "_" + dateStr + ".m4a";
        
        currentOutputPath = new File(recordingsDir, fileName).getAbsolutePath();

        // Инициализация MediaRecorder
        mediaRecorder = new MediaRecorder();
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Для Android 12+ требуем явное разрешение
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            mediaRecorder.setAudioEncodingBitRate(128000); // 128 kbps
            mediaRecorder.setAudioSamplingRate(44100); // 44.1 kHz
        } else {
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            mediaRecorder.setAudioEncodingBitRate(128000);
            mediaRecorder.setAudioSamplingRate(44100);
        }

        mediaRecorder.setOutputFile(currentOutputPath);

        try {
            mediaRecorder.prepare();
            mediaRecorder.start();
            startTime = System.currentTimeMillis();
            isRecording = true;
            
            Log.i(TAG, "Начата запись: " + currentOutputPath);
            
            if (listener != null) {
                listener.onRecordingStarted(currentOutputPath);
            }
        } catch (IOException e) {
            Log.e(TAG, "Ошибка при подготовке записи", e);
            release();
            throw e;
        }
    }

    /**
     * Остановить запись
     * @return Путь к сохраненному файлу
     */
    public String stopRecording() {
        if (!isRecording || mediaRecorder == null) {
            return null;
        }

        try {
            mediaRecorder.stop();
            long duration = System.currentTimeMillis() - startTime;
            
            Log.i(TAG, "Запись остановлена. Длительность: " + duration + " мс");
            
            if (listener != null) {
                listener.onRecordingStopped(currentOutputPath, duration);
            }
            
            return currentOutputPath;
        } catch (RuntimeException e) {
            Log.e(TAG, "Ошибка при остановке записи", e);
            return null;
        } finally {
            release();
        }
    }

    /**
     * Отменить запись (удалить файл)
     */
    public void cancelRecording() {
        if (!isRecording || mediaRecorder == null) {
            return;
        }

        try {
            mediaRecorder.stop();
        } catch (Exception e) {
            Log.e(TAG, "Ошибка при остановке записи", e);
        } finally {
            release();
            
            // Удаляем файл
            if (currentOutputPath != null) {
                File file = new File(currentOutputPath);
                if (file.exists()) {
                    file.delete();
                    Log.i(TAG, "Файл удален: " + currentOutputPath);
                }
            }
            
            if (listener != null) {
                listener.onRecordingCancelled();
            }
        }
    }

    /**
     * Освободить ресурсы
     */
    private void release() {
        if (mediaRecorder != null) {
            try {
                mediaRecorder.release();
            } catch (Exception e) {
                Log.e(TAG, "Ошибка при освобождении ресурсов", e);
            }
            mediaRecorder = null;
        }
        isRecording = false;
        currentOutputPath = null;
    }

    /**
     * Проверить, идет ли запись
     */
    public boolean isRecording() {
        return isRecording;
    }

    /**
     * Получить текущую длительность записи (мс)
     */
    public long getCurrentDuration() {
        if (!isRecording) {
            return 0;
        }
        return System.currentTimeMillis() - startTime;
    }

    /**
     * Получить текущий путь к файлу
     */
    public String getCurrentOutputPath() {
        return currentOutputPath;
    }

    /**
     * Установить слушатель событий записи
     */
    public void setRecordingListener(RecordingListener listener) {
        this.listener = listener;
    }

    /**
     * Интерфейс для прослушивания событий записи
     */
    public interface RecordingListener {
        void onRecordingStarted(String filePath);
        void onRecordingStopped(String filePath, long duration);
        void onRecordingCancelled();
        void onError(Exception error);
    }
}
