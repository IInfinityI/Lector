package com.example.lector;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
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
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.adapters.LectureAdapter;
import com.example.lector.models.Lecture;
import com.example.lector.databinding.FragmentLectureListBinding;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Фрагмент списка лекций - главный экран приложения.
 * Отображает все записанные лекции с поиском и фильтрацией.
 */
public class LectureListFragment extends Fragment {
    
    private static final int PERMISSION_REQUEST_CODE = 100;
    private static final String[] REQUIRED_PERMISSIONS = {
        Manifest.permission.RECORD_AUDIO,
        Manifest.permission.WRITE_EXTERNAL_STORAGE,
        Manifest.permission.READ_EXTERNAL_STORAGE,
        Manifest.permission.CAMERA
    };
    
    private FragmentLectureListBinding binding;
    private LectureAdapter adapter;
    private List<Lecture> lectureList;
    private com.example.lector.data.LectureRepository repository;
    
    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, 
                           @Nullable ViewGroup container,
                           @Nullable Bundle savedInstanceState) {
        binding = FragmentLectureListBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        setupRecyclerView();
        setupSearch();
        loadLectures();
        
        binding.fabNewLecture.setOnClickListener(v -> {
            if (checkPermissions()) {
                navigateToRecording();
            } else {
                requestPermissions();
            }
        });
    }
    
    private void setupRecyclerView() {
        lectureList = new ArrayList<>();
        adapter = new LectureAdapter(lectureList, this::onLectureClick);
        
        binding.recyclerViewLectures.setLayoutManager(new LinearLayoutManager(getContext()));
        binding.recyclerViewLectures.setAdapter(adapter);
    }
    
    private void setupSearch() {
        binding.searchView.setOnQueryTextListener(new androidx.appcompat.widget.SearchView.OnQueryTextListener() {
            @Override
            public boolean onQueryTextSubmit(String query) {
                filterLectures(query);
                return true;
            }
            
            @Override
            public boolean onQueryTextChange(String newText) {
                filterLectures(newText);
                return true;
            }
        });
    }
    
    private void loadLectures() {
        // Загрузка реальных лекций из JSON-хранилища (filesDir/lectures)
        lectureList.clear();
        lectureList.addAll(repository.loadAll());

        adapter.notifyDataSetChanged();

        if (lectureList.isEmpty()) {
            binding.emptyState.setVisibility(View.VISIBLE);
            binding.recyclerViewLectures.setVisibility(View.GONE);
        } else {
            binding.emptyState.setVisibility(View.GONE);
            binding.recyclerViewLectures.setVisibility(View.VISIBLE);
        }
    }

    private void filterLectures(String query) {
        List<Lecture> filtered = new ArrayList<>();
        String lowerQuery = query.toLowerCase();
        
        for (Lecture lecture : lectureList) {
            if (lecture.getSubject().toLowerCase().contains(lowerQuery)) {
                filtered.add(lecture);
            }
        }
        
        adapter.updateList(filtered);
    }
    
    private void onLectureClick(Lecture lecture) {
        // Открытие лекции для просмотра/редактирования
        Bundle args = new Bundle();
        args.putString("lecture_id", lecture.getId());
        
        EditorFragment fragment = new EditorFragment();
        fragment.setArguments(args);
        
        requireActivity().getSupportFragmentManager()
            .beginTransaction()
            .replace(R.id.nav_host_fragment_content_main, fragment)
            .addToBackStack(null)
            .commit();
    }
    
    private void navigateToRecording() {
        RecordingFragment fragment = new RecordingFragment();
        requireActivity().getSupportFragmentManager()
            .beginTransaction()
            .replace(R.id.nav_host_fragment_content_main, fragment)
            .addToBackStack(null)
            .commit();
    }
    
    private boolean checkPermissions() {
        for (String permission : REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(requireContext(), permission) 
                    != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }
    
    private void requestPermissions() {
        ActivityCompat.requestPermissions(
            requireActivity(),
            REQUIRED_PERMISSIONS,
            PERMISSION_REQUEST_CODE
        );
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, 
                                         @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            
            if (allGranted) {
                navigateToRecording();
            } else {
                Toast.makeText(getContext(), 
                    "Разрешения необходимы для работы приложения", 
                    Toast.LENGTH_LONG).show();
            }
        }
    }
    
    @Override
    public void onResume() {
        super.onResume();
        // Обновляем список после возврата с экрана записи
        if (repository != null) loadLectures();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
