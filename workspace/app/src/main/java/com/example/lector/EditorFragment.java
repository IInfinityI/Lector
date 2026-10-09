package com.example.lector;

import android.media.MediaPlayer;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.SeekBar;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.lector.adapters.ContentBlockAdapter;
import com.example.lector.data.LectureRepository;
import com.example.lector.models.Lecture;
import com.example.lector.databinding.FragmentEditorBinding;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.text.SimpleDateFormat;
import java.util.Locale;

/**
 * Фрагмент редактора лекции - просмотр и редактирование записанной лекции.
 * Данные загружаются из LectureRepository (JSON-хранилище, совместимое с модами).
 * Поддерживает синхронизацию аудио↔текст: клик по блоку перематывает запись,
 * при воспроизведении активный блок подсвечивается.
 */
public class EditorFragment extends Fragment {

    private FragmentEditorBinding binding;
    private Lecture lecture;
    private String lectureId;
    private LectureRepository repository;

    // Аудиоплеер и синхронизация аудио↔текст
    @Nullable private MediaPlayer mediaPlayer;
    private boolean playerReady = false;
    private final Handler uiHandler = new Handler(Looper.getMainLooper());
    private ContentBlockAdapter blockAdapter;

    private final Runnable progressTicker = new Runnable() {
        @Override
        public void run() {
            if (mediaPlayer != null && playerReady && mediaPlayer.isPlaying()) {
                int pos = mediaPlayer.getCurrentPosition();
                binding.seekBar.setProgress(pos);
                binding.textCurrentTime.setText(formatDuration(pos));
                if (blockAdapter != null) {
                    blockAdapter.setPlayingTimestamp(pos);
                }
                uiHandler.postDelayed(this, 500);
            }
        }
    };

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                           @Nullable ViewGroup container,
                           @Nullable Bundle savedInstanceState) {
        binding = FragmentEditorBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        repository = new LectureRepository(requireContext());

        lectureId = getArguments() != null ?
            getArguments().getString("lecture_id") : null;

        if (lectureId != null) {
            loadLecture(lectureId);
        } else {
            // Новая незаписанная лекция — создаём и сразу сохраняем
            lecture = new Lecture("Новая лекция", System.currentTimeMillis());
            repository.save(lecture);
            this.lectureId = lecture.getId();
            updateUI();
        }

        setupToolbar();
    }

    private void loadLecture(String lectureId) {
        lecture = repository.load(lectureId);
        if (lecture == null) {
            Toast.makeText(getContext(), "Лекция не найдена", Toast.LENGTH_SHORT).show();
            requireActivity().getSupportFragmentManager().popBackStack();
            return;
        }
        updateUI();
    }

    private void updateUI() {
        if (lecture == null || binding == null) return;

        binding.textSubject.setText(lecture.getSubject());
        binding.textDate.setText(new SimpleDateFormat("dd.MM.yyyy HH:mm", Locale.getDefault())
            .format(lecture.getDate()));
        binding.textDuration.setText(formatDuration(lecture.getDuration()));

        // Отображение блоков контента (включая кастомные блоки модов)
        binding.recyclerViewBlocks.setLayoutManager(new LinearLayoutManager(getContext()));
        blockAdapter = new ContentBlockAdapter(lecture.getBlocks());
        blockAdapter.setOnBlockSeekListener(this::seekAudioTo);
        // UI-слоты модов: плагины сами рисуют свои типы блоков в списке
        blockAdapter.setPluginRegistry(
            com.example.lector.plugin.PluginManager.getInstance(requireContext()).getRegistry());
        binding.recyclerViewBlocks.setAdapter(blockAdapter);

        if (lecture.getNotes() != null) {
            binding.editNotes.setText(lecture.getNotes());
        }

        setupAudioPlayer();
    }

    /** Инициализация плеера, если у лекции есть существующий аудиофайл. */
    private void setupAudioPlayer() {
        String path = lecture.getAudioPath();
        File audioFile = path != null ? new File(path) : null;
        boolean hasAudio = audioFile != null && audioFile.exists();

        binding.btnPlayPause.setEnabled(hasAudio);
        binding.seekBar.setEnabled(hasAudio);
        if (!hasAudio) {
            binding.btnPlayPause.setAlpha(0.3f);
            return;
        }

        releasePlayer();
        mediaPlayer = new MediaPlayer();
        try {
            mediaPlayer.setDataSource(audioFile.getAbsolutePath());
            mediaPlayer.setOnPreparedListener(mp -> {
                playerReady = true;
                binding.seekBar.setMax(mp.getDuration());
            });
            mediaPlayer.setOnCompletionListener(mp -> {
                stopTicker();
                binding.btnPlayPause.setImageResource(android.R.drawable.ic_media_play);
                if (blockAdapter != null) blockAdapter.setPlayingTimestamp(-1);
            });
            mediaPlayer.setOnErrorListener((mp, what, extra) -> {
                playerReady = false;
                Toast.makeText(getContext(), "Не удалось воспроизвести аудио",
                    Toast.LENGTH_SHORT).show();
                return true;
            });
            mediaPlayer.prepareAsync();
        } catch (Exception e) {
            Toast.makeText(getContext(), "Аудио недоступно: " + e.getMessage(),
                Toast.LENGTH_SHORT).show();
        }

        binding.btnPlayPause.setOnClickListener(v -> togglePlayPause());
        binding.seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser && playerReady && mediaPlayer != null) {
                    mediaPlayer.seekTo(progress);
                    binding.textCurrentTime.setText(formatDuration(progress));
                    if (blockAdapter != null) blockAdapter.setPlayingTimestamp(progress);
                }
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) { }
            @Override public void onStopTrackingTouch(SeekBar seekBar) { }
        });
    }

    private void togglePlayPause() {
        if (mediaPlayer == null || !playerReady) return;
        if (mediaPlayer.isPlaying()) {
            mediaPlayer.pause();
            binding.btnPlayPause.setImageResource(android.R.drawable.ic_media_play);
            stopTicker();
        } else {
            mediaPlayer.start();
            binding.btnPlayPause.setImageResource(android.R.drawable.ic_media_pause);
            uiHandler.post(progressTicker);
        }
    }

    /** Синхронизация текст→аудио: перемотка по клику на блок и автоскролл к нему. */
    private void seekAudioTo(long timestampMs) {
        if (mediaPlayer == null || !playerReady) {
            Toast.makeText(getContext(), "Аудиозапись недоступна", Toast.LENGTH_SHORT).show();
            return;
        }
        mediaPlayer.seekTo((int) timestampMs);
        binding.seekBar.setProgress((int) timestampMs);
        binding.textCurrentTime.setText(formatDuration(timestampMs));
        if (blockAdapter != null) blockAdapter.setPlayingTimestamp(timestampMs);
        if (!mediaPlayer.isPlaying()) {
            togglePlayPause(); // стартуем воспроизведение с выбранного места
        }
    }

    private void stopTicker() {
        uiHandler.removeCallbacks(progressTicker);
    }

    private void releasePlayer() {
        stopTicker();
        playerReady = false;
        if (mediaPlayer != null) {
            try { mediaPlayer.release(); } catch (Exception ignored) { }
            mediaPlayer = null;
        }
    }

    private String formatDuration(long ms) {
        long seconds = ms / 1000;
        return String.format(Locale.getDefault(), "%02d:%02d:%02d",
            seconds / 3600, (seconds % 3600) / 60, seconds % 60);
    }

    private void setupToolbar() {
        binding.toolbar.setNavigationOnClickListener(v -> {
            requireActivity().getSupportFragmentManager().popBackStack();
        });

        binding.btnExport.setOnClickListener(v -> exportLecture());
        binding.btnDelete.setOnClickListener(v -> deleteLecture());
    }

    private void exportLecture() {
        if (lecture == null) return;

        // Сохраняем заметки обратно в лекцию перед экспортом
        if (binding.editNotes.getText() != null) {
            lecture.setNotes(binding.editNotes.getText().toString());
            repository.save(lecture);
        }

        String markdown = lecture.toMarkdown(
            com.example.lector.plugin.PluginManager.getInstance(requireContext()).getRegistry());
        File dir = new File(requireContext().getExternalFilesDir(null), "exports");
        if (!dir.exists()) dir.mkdirs();
        File out = new File(dir, lecture.getSubjectSafe().replaceAll("[^\\w\\u0400-\\u04FF -]", "_")
            + ".md");
        try (OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(out), "UTF-8")) {
            w.write(markdown);
            Toast.makeText(getContext(), "Экспортировано в " + out.getName(),
                Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(getContext(), "Ошибка экспорта: " + e.getMessage(),
                Toast.LENGTH_LONG).show();
        }
    }

    private void deleteLecture() {
        if (lecture != null) {
            repository.delete(lecture.getId());
            Toast.makeText(getContext(), "Лекция удалена", Toast.LENGTH_SHORT).show();
        }
        requireActivity().getSupportFragmentManager().popBackStack();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        releasePlayer();
        binding = null;
    }
}
