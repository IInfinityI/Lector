package com.example.lector;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
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
        
        // Запрос названия предмета
        binding.editSubject.setText(getArguments() != null ? 
            getArguments().getString("subject", "") : "");
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
            recorderService.startRecording(subject);
            transcriptionService.startListening();
            
            isRecording = true;
            isPaused = false;
            recordingStartTime = System.currentTimeMillis();
            
            updateUIForRecording();
            
        } catch (IOException e) {
            Toast.makeText(getContext(), "Ошибка записи: " + e.getMessage(), 
                Toast.LENGTH_LONG).show();
        }
    }
    
    private void stopRecording() {
        recorderService.stopRecording();
        transcriptionService.stopListening();
        
        isRecording = false;
        isPaused = false;
        
        updateUIForStopped();
    }
    
    private void pauseRecording() {
        transcriptionService.cancelListening();
        isPaused = true;
        updateUIForPaused();
    }
    
    private void resumeRecording() {
        transcriptionService.startListening();
        isPaused = false;
        updateUIForRecording();
    }
    
    private void finishRecording() {
        if (currentLecture != null) {
            currentLecture.setBlocks(contentBlocks);
            // Сохранение в базу данных
            Toast.makeText(getContext(), "Лекция сохранена", Toast.LENGTH_SHORT).show();
        }
        
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
        ActivityCompat.requestPermissions(requireActivity(),
            new String[]{Manifest.permission.RECORD_AUDIO},
            PERMISSION_REQUEST_CODE);
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
            // Анализ текста и создание блока
            ContentBlock block = analyzerService.analyzeText(newText, 
                System.currentTimeMillis() - recordingStartTime);
            
            if (block != null) {
                // Определение спикера
                diarizationService.identifySpeaker(block, newText);
                contentBlocks.add(block);
                blockAdapter.notifyDataSetChanged();
                
                // Прокрутка к новому блоку
                binding.recyclerViewContent.scrollToPosition(contentBlocks.size() - 1);
            }
            
            binding.transcriptionStatus.setText(newText);
        });
    }
    
    @Override
    public void onPartialText(String partialText) {
        requireActivity().runOnUiThread(() -> {
            binding.transcriptionHint.setText(partialText);
        });
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
