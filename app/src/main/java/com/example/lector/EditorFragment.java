package com.example.lector;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.lector.models.Lecture;
import com.example.lector.databinding.FragmentEditorBinding;

/**
 * Фрагмент редактора лекции - просмотр и редактирование записанной лекции.
 */
public class EditorFragment extends Fragment {
    
    private FragmentEditorBinding binding;
    private Lecture lecture;
    
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
        
        String lectureId = getArguments() != null ? 
            getArguments().getString("lecture_id") : null;
        
        if (lectureId != null) {
            loadLecture(lectureId);
        }
        
        setupToolbar();
    }
    
    private void loadLecture(String lectureId) {
        // Загрузка лекции из базы данных
        // В демо-режиме создаем пустую лекцию
        lecture = new Lecture("Загруженная лекция", System.currentTimeMillis());
        
        updateUI();
    }
    
    private void updateUI() {
        if (lecture != null) {
            binding.textSubject.setText(lecture.getSubject());
            // Отображение блоков контента
        }
    }
    
    private void setupToolbar() {
        binding.toolbar.setNavigationOnClickListener(v -> {
            requireActivity().getSupportFragmentManager().popBackStack();
        });
        
        binding.btnExport.setOnClickListener(v -> exportLecture());
        binding.btnDelete.setOnClickListener(v -> deleteLecture());
    }
    
    private void exportLecture() {
        // Экспорт в Markdown/PDF
        if (lecture != null) {
            String markdown = lecture.toMarkdown();
            // Сохранение файла
        }
    }
    
    private void deleteLecture() {
        // Удаление лекции
        requireActivity().getSupportFragmentManager().popBackStack();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
