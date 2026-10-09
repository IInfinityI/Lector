package com.example.lector;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
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
 */
public class EditorFragment extends Fragment {

    private FragmentEditorBinding binding;
    private Lecture lecture;
    private String lectureId;
    private LectureRepository repository;

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
        binding.recyclerViewBlocks.setAdapter(new ContentBlockAdapter(lecture.getBlocks()));

        if (lecture.getNotes() != null) {
            binding.editNotes.setText(lecture.getNotes());
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

        String markdown = lecture.toMarkdown();
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
        binding = null;
    }
}
