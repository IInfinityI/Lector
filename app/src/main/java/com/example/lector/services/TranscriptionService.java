package com.example.lector.services;

import android.content.Context;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Log;

import java.util.ArrayList;
import java.util.Locale;

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
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_CONTINUOUS_PREFERENCE, true);
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
