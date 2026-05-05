package com.example.lector.adapters;

import android.view.LayoutInflater;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.R;
import com.example.lector.models.Lecture;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Адаптер для отображения списка лекций в RecyclerView.
 */
public class LectureAdapter extends RecyclerView.Adapter<LectureAdapter.LectureViewHolder> {
    
    private List<Lecture> lectureList;
    private OnLectureClickListener listener;
    private SimpleDateFormat dateFormat;
    private SimpleDateFormat timeFormat;
    
    public interface OnLectureClickListener {
        void onLectureClick(Lecture lecture);
    }
    
    public LectureAdapter(List<Lecture> lectureList, OnLectureClickListener listener) {
        this.lectureList = new ArrayList<>(lectureList);
        this.listener = listener;
        this.dateFormat = new SimpleDateFormat("dd MMMM yyyy", Locale.getDefault());
        this.timeFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
    }
    
    @NonNull
    @Override
    public LectureViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
            .inflate(R.layout.item_lecture, parent, false);
        return new LectureViewHolder(view);
    }
    
    @Override
    public void onBindViewHolder(@NonNull LectureViewHolder holder, int position) {
        Lecture lecture = lectureList.get(position);
        holder.bind(lecture);
    }
    
    @Override
    public int getItemCount() {
        return lectureList.size();
    }
    
    public void updateList(List<Lecture> newList) {
        this.lectureList = new ArrayList<>(newList);
        notifyDataSetChanged();
    }
    
    class LectureViewHolder extends RecyclerView.ViewHolder {
        private TextView textSubject;
        private TextView textDate;
        private TextView textDuration;
        private TextView textBlocksCount;
        
        public LectureViewHolder(@NonNull View itemView) {
            super(itemView);
            textSubject = itemView.findViewById(R.id.text_subject);
            textDate = itemView.findViewById(R.id.text_date);
            textDuration = itemView.findViewById(R.id.text_duration);
            textBlocksCount = itemView.findViewById(R.id.text_blocks_count);
            
            itemView.setOnClickListener(v -> {
                int position = getAdapterPosition();
                if (position != RecyclerView.NO_POSITION && listener != null) {
                    listener.onLectureClick(lectureList.get(position));
                }
            });
        }
        
        public void bind(Lecture lecture) {
            textSubject.setText(lecture.getSubject());
            textDate.setText(dateFormat.format(new Date(lecture.getDate())));
            
            long durationSeconds = lecture.getDuration() / 1000;
            long hours = durationSeconds / 3600;
            long minutes = (durationSeconds % 3600) / 60;
            long seconds = durationSeconds % 60;
            String durationStr = String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, minutes, seconds);
            textDuration.setText(durationStr);
            
            int blocksCount = lecture.getBlocks().size();
            textBlocksCount.setText(itemView.getContext().getString(R.string.lecture_blocks) + " " + blocksCount);
        }
    }
}
