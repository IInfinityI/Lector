package com.example.lector.services;

import android.content.Context;
import android.util.Log;

import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.MathBlock;
import com.example.lector.models.TextBlock;
import com.example.lector.utils.NumberUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Сервис для определения спикеров (Speaker Diarization).
 * Различает говорящих и присваивает им идентификаторы.
 * 
 * В полной версии использует ML-модели для распознавания голоса.
 * В базовой версии использует эвристики на основе паттернов речи.
 */
public class SpeakerDiarizationService {
    private static final String TAG = "SpeakerDiarization";
    
    private Context context;
    private int currentSpeakerId;
    private List<SpeakerSegment> segments;
    private SpeakerChangeListener listener;
    
    // Паттерны для определения типа спикера
    private static final Pattern TEACHER_PATTERNS = Pattern.compile(
        "(запомните|важно|обратите внимание|рассмотрим|изучим|тема урока|" +
        "домашнее задание|контрольная работа|экзамен|лекция|параграф|глава)",
        Pattern.CASE_INSENSITIVE
    );
    
    private static final Pattern STUDENT_PATTERNS = Pattern.compile(
        "(вопрос|можно спросить|не понял|повторите|как решить|что значит|" +
        "а если|почему|зачем|когда будет)",
        Pattern.CASE_INSENSITIVE
    );

    public SpeakerDiarizationService(Context context) {
        this.context = context.getApplicationContext();
        this.currentSpeakerId = 0;
        this.segments = new ArrayList<>();
    }

    /**
     * Обработать текстовый блок и определить спикера
     */
    public int identifySpeaker(ContentBlock block, String text) {
        if (text == null || text.isEmpty()) {
            return currentSpeakerId;
        }

        String lowerText = text.toLowerCase();
        
        // Проверяем паттерны преподавателя
        Matcher teacherMatcher = TEACHER_PATTERNS.matcher(lowerText);
        boolean isTeacher = teacherMatcher.find();
        
        // Проверяем паттерны студента
        Matcher studentMatcher = STUDENT_PATTERNS.matcher(lowerText);
        boolean isStudent = studentMatcher.find();
        
        int detectedSpeakerId;
        String speakerName;
        
        if (isTeacher && !isStudent) {
            detectedSpeakerId = 0;
            speakerName = "Преподаватель";
        } else if (isStudent && !isTeacher) {
            detectedSpeakerId = 1;
            speakerName = "Студент";
        } else {
            // Если не удалось определить - оставляем текущего или используем дефолтного
            detectedSpeakerId = currentSpeakerId;
            speakerName = (currentSpeakerId == 0) ? "Преподаватель" : "Студент";
        }

        // Проверяем смену спикера
        if (detectedSpeakerId != currentSpeakerId) {
            Log.d(TAG, "Смена спикера: " + currentSpeakerId + " -> " + detectedSpeakerId);
            
            // Завершаем предыдущий сегмент
            if (!segments.isEmpty()) {
                SpeakerSegment lastSegment = segments.get(segments.size() - 1);
                lastSegment.setEndTime(System.currentTimeMillis());
            }
            
            // Начинаем новый сегмент
            SpeakerSegment newSegment = new SpeakerSegment(
                detectedSpeakerId,
                System.currentTimeMillis(),
                block.getId()
            );
            segments.add(newSegment);
            
            currentSpeakerId = detectedSpeakerId;
            
            if (listener != null) {
                listener.onSpeakerChanged(detectedSpeakerId, speakerName);
            }
        }

        // Присваиваем спикера блоку
        block.setSpeakerId(currentSpeakerId);
        block.setSpeakerName(speakerName);

        return currentSpeakerId;
    }

    /**
     * Получить текущего спикера
     */
    public int getCurrentSpeakerId() {
        return currentSpeakerId;
    }

    /**
     * Получить все сегменты речи
     */
    public List<SpeakerSegment> getSegments() {
        return new ArrayList<>(segments);
    }

    /**
     * Сбросить состояние (начать новую лекцию)
     */
    public void reset() {
        currentSpeakerId = 0;
        segments.clear();
        Log.i(TAG, "Состояние сброшено");
    }

    /**
     * Установить слушатель событий смены спикера
     */
    public void setSpeakerChangeListener(SpeakerChangeListener listener) {
        this.listener = listener;
    }

    /**
     * Интерфейс для прослушивания событий смены спикера
     */
    public interface SpeakerChangeListener {
        void onSpeakerChanged(int speakerId, String speakerName);
    }

    /**
     * Сегмент речи одного спикера
     */
    public static class SpeakerSegment {
        private int speakerId;
        private long startTime;
        private Long endTime; // null если сегмент активен
        private String startBlockId;

        public SpeakerSegment(int speakerId, long startTime, String blockId) {
            this.speakerId = speakerId;
            this.startTime = startTime;
            this.startBlockId = blockId;
        }

        public int getSpeakerId() { return speakerId; }
        public long getStartTime() { return startTime; }
        public Long getEndTime() { return endTime; }
        public void setEndTime(long endTime) { this.endTime = endTime; }
        public String getStartBlockId() { return startBlockId; }

        /**
         * Получить длительность сегмента (мс)
         */
        public long getDuration() {
            if (endTime == null) {
                return System.currentTimeMillis() - startTime;
            }
            return endTime - startTime;
        }
    }
}
