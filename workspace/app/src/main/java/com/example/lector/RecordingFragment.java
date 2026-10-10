package com.example.lector;

import android.content.Intent;
import android.os.Build;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.lector.adapters.ContentBlockAdapter;
import com.example.lector.models.ContentBlock;
import com.example.lector.models.Lecture;
import com.example.lector.models.TextBlock;
import com.example.lector.services.AudioRecorderService;
import com.example.lector.services.ContentAnalyzerService;
import com.example.lector.services.SpeakerDiarizationService;
import com.example.lector.services.TranscriptionService;
import com.example.lector.databinding.FragmentRecordingBinding;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Фрагмент записи лекции - основной экран записи.
 * Обрабатывает аудио, транскрибацию и создание блоков контента.
 */
public class RecordingFragment extends Fragment implements 
        AudioRecorderService.RecordingListener,
        TranscriptionService.TranscriptionListener,
        SpeakerDiarizationService.SpeakerChangeListener {
    
    private static final int PERMISSION_REQUEST_CODE = 101;
    
    private FragmentRecordingBinding binding;
    private AudioRecorderService recorderService;
    private TranscriptionService transcriptionService;
    private ContentAnalyzerService analyzerService;
    private SpeakerDiarizationService diarizationService;
    
    private Lecture currentLecture;
    private ContentBlockAdapter blockAdapter;
    private List<ContentBlock> contentBlocks;
    
    private Handler timerHandler;
    private Runnable timerRunnable;
    private long recordingStartTime;
    private boolean isRecording = false;
    private boolean isPaused = false;

    // ===== Живая лента (печать в реальном времени) =====
    private final StringBuilder liveCommitted = new StringBuilder();   // подтверждённые строки
    private String liveCurrentLine = "";                              // текущая распознаваемая строка
    private int liveRevealedChars = 0;                                // сколько символов уже "напечатано"
    private static final int LIVE_PRINT_DELAY_MS = 45;                // скорость печати, мс/символ
    private static final int LIVE_MAX_TAIL_LINES = 200;               // ограничение памяти ленты
    private final Handler livePrintHandler = new Handler(Looper.getMainLooper());
    private final Runnable livePrintRunnable = new Runnable() {
        @Override
        public void run() {
            if (liveRevealedChars < liveCurrentLine.length()) {
                liveRevealedChars++;
                updateLiveTranscriptView();
                livePrintHandler.postDelayed(this, LIVE_PRINT_DELAY_MS);
            }
        }
    };

    /**
     * Обновление частичного (ещё не подтверждённого) результата распознавания.
     * Печатается посимвольно, чтобы глаза успевали за текстом.
     */
    private void onPartialRecognized(String partial) {
        if (!isRecording || isPaused) return;
        String p = partial == null ? "" : partial.trim();
        if (p.startsWith(liveCurrentLine)) {
            liveCurrentLine = p;                       // строка растёт — просто допечатываем
        } else if (p.length() >= liveCurrentLine.length()) {
            liveCurrentLine = p;                       // распознавание уточнило строку целиком
        }
        // если частичный результат стал короче текущего — ждём подтверждения, не переписываем назад
        if (liveRevealedChars < liveCurrentLine.length()) {
            livePrintHandler.removeCallbacks(livePrintRunnable);
            livePrintHandler.post(livePrintRunnable);
        }
    }

    /**
     * Подтверждение финальной строки: строка фиксируется в ленте с префиксом спикера.
     */
    private void commitLiveLine(String text, String speakerName) {
        livePrintHandler.removeCallbacks(livePrintRunnable);
        String line = (speakerName != null && !speakerName.isEmpty())
            ? speakerName + ": " + text : text;
        if (liveCommitted.length() > 0) liveCommitted.append('\n');
        liveCommitted.append(line);
        trimLiveTail();
        liveCurrentLine = "";
        liveRevealedChars = 0;
        updateLiveTranscriptView();
    }

    private void trimLiveTail() {
        int idx = liveCommitted.length();
        int count = 0;
        while (idx > 0 && count <= LIVE_MAX_TAIL_LINES) {
            idx = liveCommitted.lastIndexOf("\n", idx - 1);
            count++;
        }
        if (count > LIVE_MAX_TAIL_LINES && idx >= 0) {
            liveCommitted.delete(0, idx + 1);
        }
    }

    private void updateLiveTranscriptView() {
        if (binding == null || !isAdded()) return;
        StringBuilder sb = new StringBuilder(liveCommitted);
        if (!liveCurrentLine.isEmpty()) {
            if (sb.length() > 0) sb.append('\n');
            sb.append(liveCurrentLine, 0, liveRevealedChars);
            if (liveRevealedChars < liveCurrentLine.length()) {
                sb.append('▌');                        // каретка «печатающегося» текста
            }
        }
        binding.tvLiveTranscript.setText(sb.toString());
        binding.liveScroll.post(() ->
            binding.liveScroll.fullScroll(android.view.View.FOCUS_DOWN));
    }
    
    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                           @Nullable ViewGroup container,
                           @Nullable Bundle savedInstanceState) {
        binding = FragmentRecordingBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        initServices();
        setupRecyclerView();
        setupButtons();
        startTimer();

        // Дата начала лекции ставится автоматически (видно до старта,
        // фиксируется в Lecture.date при нажатии «Старт»)
        binding.textLectureDate.setText(
            com.example.lector.plugin.builtin.SubjectPickerPlugin
                .dateLabel(System.currentTimeMillis()));

        // Название предмета: подсказки из ранее сохранённых названий
        // (реестр SubjectRegistry + мод SubjectPicker)
        String savedSubject = getArguments() != null ?
            getArguments().getString("subject", "") : "";
        if (savedSubject.isEmpty()) {
            List<com.example.lector.data.SubjectRegistry.Entry> recentSubjects =
                new com.example.lector.data.SubjectRegistry(requireContext()).recent(10);
            if (!recentSubjects.isEmpty()) savedSubject = recentSubjects.get(0).name;
        }
        binding.editSubject.setText(savedSubject);
        binding.editSubject.setSelection(binding.editSubject.getText().length());
        refreshSubjectSuggestions();

        // Уведомляем моды об готовности экрана записи (UI-слот v1.5)
        com.example.lector.plugin.PluginManager.getInstance(requireContext())
            .notifyScreenReady("recording", binding.getRoot());
    }

    /** Перезаполняет выпадающий список предметов реестра. */
    private void refreshSubjectSuggestions() {
        java.util.List<String> names = new ArrayList<>();
        for (com.example.lector.data.SubjectRegistry.Entry e :
                new com.example.lector.data.SubjectRegistry(requireContext()).recent(50)) {
            names.add(e.name);
        }
        ArrayAdapter<String> adapter = new ArrayAdapter<>(requireContext(),
            android.R.layout.simple_dropdown_item_1line, names);
        binding.editSubject.setAdapter(adapter);
    }
    
    private void initServices() {
        recorderService = new AudioRecorderService(requireContext());
        transcriptionService = new TranscriptionService(requireContext());
        analyzerService = new ContentAnalyzerService();
        diarizationService = new SpeakerDiarizationService(requireContext());
        
        recorderService.setRecordingListener(this);
        transcriptionService.setTranscriptionListener(this);
        diarizationService.setSpeakerChangeListener(this);
        
        contentBlocks = new ArrayList<>();
        currentLecture = null;
    }
    
    private void setupRecyclerView() {
        blockAdapter = new ContentBlockAdapter(contentBlocks);
        binding.recyclerViewContent.setLayoutManager(new LinearLayoutManager(getContext()));
        binding.recyclerViewContent.setAdapter(blockAdapter);
    }
    
    private void setupButtons() {
        binding.btnStartStop.setOnClickListener(v -> {
            if (!isRecording) {
                startRecording();
            } else {
                stopRecording();
            }
        });
        
        binding.btnPauseResume.setOnClickListener(v -> {
            if (isPaused) {
                resumeRecording();
            } else {
                pauseRecording();
            }
        });
        
        binding.btnFinish.setOnClickListener(v -> finishRecording());
        
        binding.btnAddMath.setOnClickListener(v -> addMathBlock());
        binding.btnAddTable.setOnClickListener(v -> addTableBlock());
        binding.btnAddPhoto.setOnClickListener(v -> takePhoto());
    }
    
    private void startRecording() {
        String subject = binding.editSubject.getText().toString().trim();
        if (subject.isEmpty()) {
            Toast.makeText(getContext(), "Введите название предмета", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!checkAudioPermission()) {
            requestAudioPermission();
            return;
        }
        
        try {
            currentLecture = new Lecture(subject, System.currentTimeMillis());
            // Название предмета сохраняется в реестре — оно появится в подсказках
            // при следующей лекции (экран записи, выпадающий список «Предмет»)
            new com.example.lector.data.SubjectRegistry(requireContext()).remember(subject);
            recorderService.startRecording(subject);
            transcriptionService.startListening();

            // Foreground-сервис: запись не прерывается при сворачивании приложения
            try {
                Intent fg = new Intent(requireContext(),
                        com.example.lector.services.RecordingForegroundService.class);
                fg.putExtra(com.example.lector.services.RecordingForegroundService.EXTRA_PATH,
                        recorderService.getCurrentOutputPath());
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    requireContext().startForegroundService(fg);
                } else {
                    requireContext().startService(fg);
                }
            } catch (Exception ignored) {
            }
            
            isRecording = true;
            isPaused = false;
            recordingStartTime = System.currentTimeMillis();

            // Живая лента вместо структурированного списка на время записи
            liveCommitted.setLength(0);
            liveCurrentLine = "";
            liveRevealedChars = 0;
            binding.tvLiveTranscript.setText("");
            binding.liveScroll.setVisibility(View.VISIBLE);
            binding.recyclerViewContent.setVisibility(View.GONE);


            // Событие для модов: начало записи
            com.example.lector.plugin.PluginManager.getInstance(requireContext())
                .getEventBus().publish(
                    com.example.lector.plugin.EventBus.Event.RECORDING_STARTED,
                    currentLecture);
            updateUIForRecording();
            
        } catch (IOException e) {
            Toast.makeText(getContext(), "Ошибка записи: " + e.getMessage(), 
                Toast.LENGTH_LONG).show();
        }
    }
    
    private void stopRecording() {
        recorderService.stopRecording();
        transcriptionService.stopListening();

        try {
            requireContext().stopService(new Intent(requireContext(),
                    com.example.lector.services.RecordingForegroundService.class));
        } catch (Exception ignored) {
        }
        
        isRecording = false;
        isPaused = false;

        // После остановки — структурированный список блоков поверх живой ленты
        livePrintHandler.removeCallbacks(livePrintRunnable);
        binding.liveScroll.setVisibility(View.GONE);
        binding.recyclerViewContent.setVisibility(View.VISIBLE);
        

        // Событие для модов: конец записи
        com.example.lector.plugin.PluginManager.getInstance(requireContext())
            .getEventBus().publish(
                com.example.lector.plugin.EventBus.Event.RECORDING_STOPPED,
                currentLecture);
        updateUIForStopped();
    }
    
    private void pauseRecording() {
        transcriptionService.cancelListening();
        isPaused = true;
        updateUIForPaused();
    }

    /** Исполнение голосовых команд диктовки (без создания блоков). */
    private void executeDictationCommand(
            com.example.lector.services.ContentAnalyzerService.DictationCommand cmd) {
        switch (cmd) {
            case NEWLINE:
                // Пустая строка в живой ленте — визуально отделяет абзацы
                commitLiveLine("", "");
                Toast.makeText(getContext(), "Новая строка", Toast.LENGTH_SHORT).show();
                break;
            case COPY_ALL:
                copyTranscriptToClipboard();
                break;
            case SAVE:
                finishRecording();
                break;
        }
    }

    /** Копирование расшифровки в буфер обмена ОС (как в «Голосовом блокноте»). */
    private void copyTranscriptToClipboard() {
        if (!isAdded()) return;
        String text = liveCommitted.toString().trim();
        if (text.isEmpty() && currentLecture != null) {
            text = currentLecture.toMarkdown();
        }
        if (text.isEmpty()) {
            Toast.makeText(getContext(), "Пока нечего копировать", Toast.LENGTH_SHORT).show();
            return;
        }
        android.content.ClipboardManager cm = (android.content.ClipboardManager)
            requireContext().getSystemService(android.content.Context.CLIPBOARD_SERVICE);
        cm.setPrimaryClip(android.content.ClipData.newPlainText("Lector", text));
        Toast.makeText(getContext(), "Текст скопирован в буфер обмена",
            Toast.LENGTH_SHORT).show();
    }
    
    private void resumeRecording() {
        transcriptionService.startListening();
        isPaused = false;
        updateUIForRecording();
    }
    
    private void finishRecording() {
        if (currentLecture == null) {
            Toast.makeText(getContext(), "Нечего сохранять — запись не была начата",
                Toast.LENGTH_SHORT).show();
            return;
        }

        currentLecture.setBlocks(contentBlocks);
        currentLecture.setDuration(System.currentTimeMillis() - recordingStartTime);

        // Пост-обработка: встроенный процессор ядра + процессоры модов
        new com.example.lector.services.CorePostProcessor().process(currentLecture);
        com.example.lector.plugin.PluginManager.getInstance(requireContext())
            .getRegistry().runPostProcessors(currentLecture);
        contentBlocks = currentLecture.getBlocks();

        // Сохранение через LectureRepository (JSON-хранилище, совместимое с модами)
        boolean saved = new com.example.lector.data.LectureRepository(requireContext())
            .save(currentLecture);

        if (saved) {
            // Событие для модов: лекция сохранена
            com.example.lector.plugin.PluginManager.getInstance(requireContext())
                .getEventBus().publish(
                    com.example.lector.plugin.EventBus.Event.LECTURE_SAVED,
                    currentLecture);
        }

        Toast.makeText(getContext(),
            saved ? "Лекция сохранена" : "Ошибка сохранения лекции",
            Toast.LENGTH_SHORT).show();

        requireActivity().getSupportFragmentManager().popBackStack();
    }
    
    private void updateUIForRecording() {
        binding.btnStartStop.setIconResource(android.R.drawable.ic_media_pause);
        binding.btnStartStop.setText(R.string.recording_stop);
        binding.btnPauseResume.setIconResource(android.R.drawable.ic_media_pause);
        binding.btnPauseResume.setText(R.string.recording_pause);
        binding.recordingStatus.setText(R.string.status_recording);
        binding.recordingStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.recording));
    }
    
    private void updateUIForPaused() {
        binding.btnPauseResume.setIconResource(android.R.drawable.ic_media_play);
        binding.btnPauseResume.setText(R.string.recording_resume);
        binding.recordingStatus.setText(R.string.status_paused);
        binding.recordingStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.paused));
    }
    
    private void updateUIForStopped() {
        binding.btnStartStop.setIconResource(android.R.drawable.ic_media_play);
        binding.btnStartStop.setText(R.string.recording_start);
        binding.recordingStatus.setText(R.string.status_stopped);
        binding.recordingStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.stopped));
    }
    
    private void startTimer() {
        timerHandler = new Handler(Looper.getMainLooper());
        timerRunnable = new Runnable() {
            @Override
            public void run() {
                if (isRecording && !isPaused) {
                    long elapsed = System.currentTimeMillis() - recordingStartTime;
                    binding.textDuration.setText(formatDuration(elapsed));
                }
                timerHandler.postDelayed(this, 1000);
            }
        };
        timerHandler.post(timerRunnable);
    }
    
    private String formatDuration(long ms) {
        long seconds = ms / 1000;
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        long secs = seconds % 60;
        return String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, minutes, secs);
    }
    
    private void addMathBlock() {
        // Добавление математического блока
        TextBlock mathBlock = new TextBlock("Математическое выражение", System.currentTimeMillis());
        contentBlocks.add(mathBlock);
        blockAdapter.notifyDataSetChanged();
    }
    
    private void addTableBlock() {
        // Добавление таблицы
        Toast.makeText(getContext(), "Создание таблицы...", Toast.LENGTH_SHORT).show();
    }
    
    private void takePhoto() {
        // Открытие камеры
        Toast.makeText(getContext(), "Открытие камеры...", Toast.LENGTH_SHORT).show();
    }
    
    private boolean checkAudioPermission() {
        return ContextCompat.checkSelfPermission(requireContext(), 
            Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }
    
    private void requestAudioPermission() {
        java.util.List<String> needed = new java.util.ArrayList<>();
        needed.add(Manifest.permission.RECORD_AUDIO);
        // На Android 13+ без POST_NOTIFICATIONS уведомление фоновой записи не покажется
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU
                && ContextCompat.checkSelfPermission(requireContext(),
                    Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS);
        }
        ActivityCompat.requestPermissions(requireActivity(),
            needed.toArray(new String[0]),
            PERMISSION_REQUEST_CODE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQUEST_CODE
                && permissions.length > 0
                && Manifest.permission.RECORD_AUDIO.equals(permissions[0])) {
            if (grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Разрешение выдано — продолжаем начатое действие
                startRecording();
            } else {
                Toast.makeText(requireContext(),
                    "Для записи лекций необходимо разрешение на микрофон",
                    Toast.LENGTH_LONG).show();
            }
        }
    }

    // ===== AudioRecorderService callbacks =====
    
    @Override
    public void onRecordingStarted(String filePath) {
        requireActivity().runOnUiThread(() -> {
            Toast.makeText(getContext(), "Запись началась", Toast.LENGTH_SHORT).show();
        });
    }
    
    @Override
    public void onRecordingStopped(String filePath, long duration) {
        requireActivity().runOnUiThread(() -> {
            if (currentLecture != null) {
                currentLecture.setAudioPath(filePath);
                currentLecture.setDuration(duration);
            }
        });
    }
    
    @Override
    public void onRecordingCancelled() {
        currentLecture = null;
    }
    
    @Override
    public void onError(Exception error) {
        requireActivity().runOnUiThread(() -> {
            Toast.makeText(getContext(), "Ошибка: " + error.getMessage(), 
                Toast.LENGTH_SHORT).show();
        });
    }
    
    // ===== TranscriptionService callbacks =====
    
    @Override
    public void onListeningStarted() {
        requireActivity().runOnUiThread(() -> {
            binding.transcriptionStatus.setText("Слушаю...");
        });
    }
    
    @Override
    public void onListeningStopped() {
        requireActivity().runOnUiThread(() -> {
            binding.transcriptionStatus.setText("");
        });
    }
    
    @Override
    public void onSpeechStarted() {
        requireActivity().runOnUiThread(() -> {
            binding.transcriptionStatus.setText("Говорите...");
        });
    }
    
    @Override
    public void onSpeechEnded() {
    }
    
    @Override
    public void onTextRecognized(String newText, String fullText) {
        requireActivity().runOnUiThread(() -> {
            // Голосовые команды управления диктовкой: «новая строка»,
            // «скопировать», «сохранить» — не создают блоков, а выполняют действие
            com.example.lector.services.ContentAnalyzerService.DictationCommand cmd =
                analyzerService.getDictationCommand(newText);
            if (cmd != null) {
                executeDictationCommand(cmd);
                return;
            }

            // Сначала моды (цепочка BlockHandler), затем встроенный анализатор ядра
            ContentBlock block = com.example.lector.plugin.PluginManager
                .getInstance(requireContext()).getRegistry()
                .handleText(newText, System.currentTimeMillis() - recordingStartTime);

            if (block == null) {
                block = analyzerService.analyzeText(newText,
                    System.currentTimeMillis() - recordingStartTime);
            }
            
            if (block != null) {
                // Определение спикера
                diarizationService.identifySpeaker(block, newText);
                contentBlocks.add(block);
                blockAdapter.notifyDataSetChanged();
                

                // События для модов
                com.example.lector.plugin.EventBus bus =
                    com.example.lector.plugin.PluginManager.getInstance(requireContext())
                        .getEventBus();
                bus.publish(com.example.lector.plugin.EventBus.Event.TRANSCRIPTION_RECEIVED, newText);
                bus.publish(com.example.lector.plugin.EventBus.Event.BLOCK_ADDED, block);
                // Прокрутка к новому блоку
                binding.recyclerViewContent.scrollToPosition(contentBlocks.size() - 1);
            }
            
            binding.transcriptionStatus.setText(newText);

            // Фиксация подтверждённой строки в живой ленте (для списывания с экрана)
            String speaker = block != null ? block.getSpeakerName() : "";
            commitLiveLine(newText, speaker);
        });
    }

    @Override
    public void onPartialText(String partialText) {
        requireActivity().runOnUiThread(() -> onPartialRecognized(partialText));
    }
    
    @Override
    public void onVolumeChanged(float rmsdB) {
        // Можно использовать для визуализации уровня звука
    }
    
    // ===== SpeakerDiarizationService callbacks =====
    
    @Override
    public void onSpeakerChanged(int speakerId, String speakerName) {
        requireActivity().runOnUiThread(() -> {
            binding.currentSpeaker.setText(speakerName);
            Toast.makeText(getContext(), "Спикер: " + speakerName, 
                Toast.LENGTH_SHORT).show();
        });
    }
    
    @Override
    public void onDestroyView() {
        livePrintHandler.removeCallbacks(livePrintRunnable);
        super.onDestroyView();
        if (timerHandler != null) {
            timerHandler.removeCallbacks(timerRunnable);
        }
        if (isRecording) {
            stopRecording();
        }
        binding = null;
    }
}
