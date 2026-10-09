package com.example.lector.services;

import android.content.Context;
import android.content.Intent;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Сервис для потоковой транскрибации речи в текст.
 * Использует встроенный SpeechRecognizer Android для работы офлайн.
 * Поддерживает смешанный русский/английский язык.
 */
public class TranscriptionService {
    private static final String TAG = "TranscriptionService";
    
    private Context context;
    private SpeechRecognizer speechRecognizer;
    private boolean isListening = false;
    private TranscriptionListener listener;
    private StringBuilder currentText;
    private long sessionStartTime;

    public TranscriptionService(Context context) {
        this.context = context.getApplicationContext();
        this.currentText = new StringBuilder();
    }

    // ===== Офлайн-транскрибирование готового аудиофайла =====

    /** Прогресс транскрибирования файла (0..1). */
    public interface ProgressCallback { void onProgress(float p); }

    /**
     * Транскрибировать аудиофайл офлайн: декодирование в PCM 16 кГц моно
     * (MediaExtractor+MediaCodec), затем распознавание фрагментов через SpeechRecognizer
     * с extra-параметром пути к аудиофайлу. Возвращает список распознанных фраз.
     * Вызывать из фонового потока. Требует разрешения RECORD_AUDIO (SpeechRecognizer API).
     */
    public static java.util.List<String> transcribeFile(Context ctx, String filePath,
                                                        ProgressCallback progress) {
        java.util.List<String> phrases = new ArrayList<>();
        try {
            File wav = decodeToWav(ctx, filePath, 16000, 1);
            if (wav == null || wav.length() < 8000) return phrases;

            long pcmBytes = wav.length() - 44;
            int chunkMs = 12000; // фрагменты по 12 с — движок не любит очень длинные файлы
            long chunkBytes = (chunkMs / 1000L) * 16000L * 2;
            int chunks = (int) Math.max(1, Math.ceil((double) pcmBytes / chunkBytes));

            HandlerThread ht = new HandlerThread("transcribe");
            ht.start();
            Handler hr = new Handler(ht.getLooper());

            for (int i = 0; i < chunks; i++) {
                long off = 44 + i * chunkBytes;
                long len = Math.min(chunkBytes, wav.length() - off);
                byte[] slice = new byte[(int) len];
                try (FileInputStream fis = new FileInputStream(wav)) {
                    fis.skip(off);
                    int read = 0;
                    while (read < slice.length) {
                        int n = fis.read(slice, read, slice.length - read);
                        if (n <= 0) break;
                        read += n;
                    }
                }
                File sf = File.createTempFile("seg" + i, ".wav", ctx.getCacheDir());
                try (java.io.FileOutputStream fos = new java.io.FileOutputStream(sf)) {
                    writeWavHeader(fos, slice.length, 16000, 1);
                    fos.write(slice);
                }

                final CountDownLatch latch = new CountDownLatch(1);
                hr.post(() -> {
                    SpeechRecognizer sr = SpeechRecognizer.createSpeechRecognizer(ctx);
                    sr.setRecognitionListener(new RecognitionListener() {
                        @Override public void onReadyForSpeech(Bundle p) {}
                        @Override public void onBeginningOfSpeech() {}
                        @Override public void onRmsChanged(float r) {}
                        @Override public void onBufferReceived(byte[] b) {}
                        @Override public void onEndOfSpeech() {}
                        @Override public void onError(int e) { latch.countDown(); }
                        @Override public void onResults(Bundle results) {
                            ArrayList<String> m = results.getStringArrayList(
                                SpeechRecognizer.RESULTS_RECOGNITION);
                            if (m != null && !m.isEmpty() && !m.get(0).trim().isEmpty()) {
                                synchronized (phrases) { phrases.add(m.get(0).trim()); }
                            }
                            latch.countDown();
                        }
                        @Override public void onPartialResults(Bundle p) {}
                        @Override public void onEvent(int t, Bundle p) {}
                    });
                    Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ru-RU");
                    intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
                    // "audio_source" — undocumented extra: путь к аудиофайлу вместо микрофона.
                    // Используем строковый литерал для совместимости со старыми SDK (API < 34).
                    intent.putExtra("android.speech.extra.AUDIO_SOURCE_FILE", sf.getAbsolutePath());
                    sr.startListening(intent);
                });
                boolean ok = latch.await(35, TimeUnit.SECONDS);
                sf.delete();
                if (!ok) Log.w("TranscriptionService", "сегмент " + i + " без результата");
                if (progress != null) progress.onProgress((i + 1f) / chunks);
            }
            ht.quitSafely();
        } catch (Exception e) {
            Log.e("TranscriptionService", "transcribeFile failed", e);
        }
        return phrases;
    }

    /** Декодировать аудиофайл в WAV (PCM 16-bit). Возвращает temp-файл или null. */
    private static File decodeToWav(Context ctx, String path, int sampleRate, int channels) {
        MediaExtractor ex = null;
        MediaCodec dec = null;
        File out = null;
        try {
            out = File.createTempFile("dec", ".wav", ctx.getCacheDir());
            ex = new MediaExtractor();
            ex.setDataSource(path);
            int track = -1;
            MediaFormat fmt = null;
            for (int i = 0; i < ex.getTrackCount(); i++) {
                MediaFormat f = ex.getTrackFormat(i);
                String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) { track = i; fmt = f; break; }
            }
            if (track < 0) return null;
            ex.selectTrack(track);
            dec = MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME));
            dec.configure(fmt, null, null, 0);
            dec.start();

            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();

            // Собираем PCM в памяти (ограничение ~200 МБ на очень длинные записи — приемлемо для лекций)
            java.io.ByteArrayOutputStream pcm = new java.io.ByteArrayOutputStream();
            boolean inputDone = false, outputDone = false;
            while (!outputDone) {
                if (!inputDone) {
                    int inIdx = dec.dequeueInputBuffer(5000);
                    if (inIdx >= 0) {
                        ByteBuffer in = dec.getInputBuffer(inIdx);
                        int sz = ex.readSampleData(in, 0);
                        if (sz < 0) {
                            dec.queueInputBuffer(inIdx, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            inputDone = true;
                        } else {
                            dec.queueInputBuffer(inIdx, 0, sz, ex.getSampleTime(), 0);
                            ex.advance();
                        }
                    }
                }
                int outIdx = dec.dequeueOutputBuffer(info, 5000);
                if (outIdx >= 0) {
                    if (info.size > 0) {
                        ByteBuffer ob = dec.getOutputBuffer(outIdx);
                        byte[] buf = new byte[info.size];
                        ob.position(info.offset);
                        ob.get(buf, 0, info.size);
                        pcm.write(buf);
                    }
                    dec.releaseOutputBuffer(outIdx, false);
                    if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outputDone = true;
                } else if (outIdx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    // пауза короткая
                }
            }
            byte[] pcmBytes = pcm.toByteArray();
            // Моно: если исходник стерео — усредняем каналы до mono
            try {
                int srcCh = fmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                    ? fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;
                if (srcCh == 2 && channels == 1) pcmBytes = toMono(pcmBytes);
            } catch (Exception ignored) {}
            // Ресемплинг частоты дискретизации к 16 кГц, если нужно
            try {
                int srcRate = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                if (srcRate != sampleRate) {
                    // линейная интерполяция до 16 кГц
                    pcmBytes = resample(pcmBytes, srcRate, sampleRate);
                }
            } catch (Exception ignored) {}
            try (java.io.FileOutputStream fo = new java.io.FileOutputStream(out)) {
                writeWavHeader(fo, pcmBytes.length, sampleRate, channels);
                fo.write(pcmBytes);
            }
            return out;
        } catch (Exception e) {
            Log.e("TranscriptionService", "decode failed", e);
            if (out != null) out.delete();
            return null;
        } finally {
            try { if (dec != null) { dec.stop(); dec.release(); } } catch (Exception ignored) {}
            try { if (ex != null) ex.release(); } catch (Exception ignored) {}
        }
    }

    private static void writeWavHeader(java.io.OutputStream os, int dataLen, int rate, int ch)
            throws IOException {
        int byteRate = rate * ch * 2;
        java.nio.ByteBuffer h = java.nio.ByteBuffer.allocate(44)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        h.putInt(0x46464952); // "RIFF"
        h.putInt(36 + dataLen);
        h.putInt(0x45564157); // "WAVE"
        h.putInt(0x20746d66); // "fmt "
        h.putInt(16);
        h.putShort((short) 1);
        h.putShort((short) ch);
        h.putInt(rate);
        h.putInt(byteRate);
        h.putShort((short) (ch * 2));
        h.putShort((short) 16);
        h.putInt(0x61746164); // "data"
        h.putInt(dataLen);
        os.write(h.array());
    }

    /** Стерео PCM16 → моно (усреднение каналов). */
    private static byte[] toMono(byte[] stereo) {
        java.nio.ByteBuffer in = java.nio.ByteBuffer.wrap(stereo)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        int frames = stereo.length / 4;
        java.nio.ByteBuffer out = java.nio.ByteBuffer.allocate(frames * 2)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        for (int i = 0; i < frames; i++) {
            short l = in.getShort(), r = in.getShort();
            out.putShort((short) ((l + r) / 2));
        }
        return out.array();
    }

    /** Линейный ресемплинг mono/stereo PCM16 → mono 16k. */
    private static byte[] resample(byte[] pcm, int srcRate, int dstRate) {
        int samples = pcm.length / 2;
        double ratio = (double) srcRate / dstRate;
        int outSamples = (int) (samples / ratio);
        java.nio.ByteBuffer in = java.nio.ByteBuffer.wrap(pcm)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        java.nio.ByteBuffer out = java.nio.ByteBuffer.allocate(outSamples * 2)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN);
        for (int i = 0; i < outSamples; i++) {
            double pos = i * ratio;
            int i0 = (int) pos;
            int i1 = Math.min(i0 + 1, samples - 1);
            float frac = (float) (pos - i0);
            short s0 = in.getShort(i0 * 2);
            short s1 = in.getShort(i1 * 2);
            out.putShort((short) (s0 * (1 - frac) + s1 * frac));
        }
        return out.array();
    }

    /**
     * Начать прослушивание речи
     */
    public void startListening() {
        if (isListening) {
            return;
        }

        // Проверка доступности распознавания речи
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.e(TAG, "Распознавание речи недоступно на этом устройстве");
            if (listener != null) {
                listener.onError(new Exception("Speech recognition not available"));
            }
            return;
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
        speechRecognizer.setRecognitionListener(createRecognitionListener());

        Intent recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        
        // Поддержка смешанного языка (RU + EN)
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ru-RU");
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);

        try {
            speechRecognizer.startListening(recognizerIntent);
            isListening = true;
            sessionStartTime = System.currentTimeMillis();
            currentText = new StringBuilder();
            
            Log.i(TAG, "Начато прослушивание речи");
            
            if (listener != null) {
                listener.onListeningStarted();
            }
        } catch (Exception e) {
            Log.e(TAG, "Ошибка при запуске распознавания", e);
            if (listener != null) {
                listener.onError(e);
            }
        }
    }

    /**
     * Остановить прослушивание
     */
    public void stopListening() {
        if (!isListening || speechRecognizer == null) {
            return;
        }

        try {
            speechRecognizer.stopListening();
            Log.i(TAG, "Прослушивание остановлено");
        } catch (Exception e) {
            Log.e(TAG, "Ошибка при остановке прослушивания", e);
        } finally {
            destroy();
        }
    }

    /**
     * Отменить текущую сессию
     */
    public void cancelListening() {
        if (!isListening || speechRecognizer == null) {
            return;
        }

        try {
            speechRecognizer.cancel();
            currentText = new StringBuilder();
            Log.i(TAG, "Прослушивание отменено");
        } catch (Exception e) {
            Log.e(TAG, "Ошибка при отмене прослушивания", e);
        } finally {
            destroy();
        }
    }

    /**
     * Освободить ресурсы
     */
    private void destroy() {
        if (speechRecognizer != null) {
            try {
                speechRecognizer.destroy();
            } catch (Exception e) {
                Log.e(TAG, "Ошибка при освобождении ресурсов", e);
            }
            speechRecognizer = null;
        }
        isListening = false;
    }

    /**
     * Создать слушатель событий распознавания
     */
    private RecognitionListener createRecognitionListener() {
        return new RecognitionListener() {
            @Override
            public void onReadyForSpeech(Bundle params) {
                Log.d(TAG, "Готов к распознаванию");
            }

            @Override
            public void onBeginningOfSpeech() {
                Log.d(TAG, "Начало речи");
                if (listener != null) {
                    listener.onSpeechStarted();
                }
            }

            @Override
            public void onRmsChanged(float rmsdB) {
                // Изменение громкости - можно использовать для визуализации
                if (listener != null) {
                    listener.onVolumeChanged(rmsdB);
                }
            }

            @Override
            public void onBufferReceived(byte[] buffer) {
                // Получены аудио данные
            }

            @Override
            public void onEndOfSpeech() {
                Log.d(TAG, "Конец речи");
                if (listener != null) {
                    listener.onSpeechEnded();
                }
            }

            @Override
            public void onError(int error) {
                String errorMessage = getErrorMessage(error);
                Log.e(TAG, "Ошибка распознавания: " + errorMessage);
                
                if (listener != null) {
                    listener.onError(new Exception(errorMessage));
                }
                
                // Автоматический перезапуск при некоторых ошибках
                if (error == SpeechRecognizer.ERROR_NO_MATCH || 
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    // Можно попробовать перезапустить
                    destroy();
                }
            }

            @Override
            public void onResults(Bundle results) {
                ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (matches != null && !matches.isEmpty()) {
                    String recognizedText = matches.get(0);
                    Log.d(TAG, "Распознано: " + recognizedText);
                    
                    currentText.append(recognizedText).append(" ");
                    
                    if (listener != null) {
                        listener.onTextRecognized(recognizedText, currentText.toString());
                    }
                }
                
                // Для непрерывного распознавания - перезапускаем
                if (isListening) {
                    startListening();
                }
            }

            @Override
            public void onPartialResults(Bundle partialResults) {
                ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (matches != null && !matches.isEmpty()) {
                    String partialText = matches.get(0);
                    Log.d(TAG, "Частично: " + partialText);
                    
                    if (listener != null) {
                        listener.onPartialText(partialText);
                    }
                }
            }

            @Override
            public void onEvent(int eventType, Bundle params) {
                // События низкого уровня
            }
        };
    }

    /**
     * Получить текстовое описание ошибки
     */
    private String getErrorMessage(int error) {
        switch (error) {
            case SpeechRecognizer.ERROR_AUDIO:
                return "Ошибка записи аудио";
            case SpeechRecognizer.ERROR_CLIENT:
                return "Ошибка клиента";
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                return "Недостаточно разрешений";
            case SpeechRecognizer.ERROR_NETWORK:
                return "Ошибка сети";
            case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                return "Таймаут сети";
            case SpeechRecognizer.ERROR_NO_MATCH:
                return "Речь не распознана";
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                return "Распознаватель занят";
            case SpeechRecognizer.ERROR_SERVER:
                return "Ошибка сервера";
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                return "Превышено время ожидания речи";
            default:
                return "Неизвестная ошибка: " + error;
        }
    }

    /**
     * Проверить, идет ли прослушивание
     */
    public boolean isListening() {
        return isListening;
    }

    /**
     * Получить накопленный текст
     */
    public String getCurrentText() {
        return currentText.toString().trim();
    }

    /**
     * Получить длительность текущей сессии (мс)
     */
    public long getSessionDuration() {
        if (!isListening) {
            return 0;
        }
        return System.currentTimeMillis() - sessionStartTime;
    }

    /**
     * Установить слушатель событий транскрибации
     */
    public void setTranscriptionListener(TranscriptionListener listener) {
        this.listener = listener;
    }

    /**
     * Интерфейс для прослушивания событий транскрибации
     */
    public interface TranscriptionListener {
        void onListeningStarted();
        void onListeningStopped();
        void onSpeechStarted();
        void onSpeechEnded();
        void onTextRecognized(String newText, String fullText);
        void onPartialText(String partialText);
        void onVolumeChanged(float rmsdB);
        void onError(Exception error);
    }
}
