package com.example.lector.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.lector.R;
import com.example.lector.models.BlockType;
import com.example.lector.models.ContentBlock;
import com.example.lector.models.HeadingBlock;
import com.example.lector.models.MathBlock;
import com.example.lector.models.TextBlock;

import java.text.SimpleDateFormat;
import java.util.List;
import java.util.Locale;

/**
 * Адаптер для отображения блоков контента в RecyclerView.
 */
public class ContentBlockAdapter extends RecyclerView.Adapter<ContentBlockAdapter.BlockViewHolder> {
    
    private List<ContentBlock> blocks;
    private SimpleDateFormat timeFormat;
    
    public ContentBlockAdapter(List<ContentBlock> blocks) {
        this.blocks = blocks;
        this.timeFormat = new SimpleDateFormat("mm:ss", Locale.getDefault());
    }
    
    @NonNull
    @Override
    public BlockViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
            .inflate(R.layout.item_content_block, parent, false);
        return new BlockViewHolder(view);
    }
    
    @Override
    public void onBindViewHolder(@NonNull BlockViewHolder holder, int position) {
        ContentBlock block = blocks.get(position);
        holder.bind(block);
    }
    
    @Override
    public int getItemCount() {
        return blocks.size();
    }
    
    @Override
    public int getItemViewType(int position) {
        return blocks.get(position).getType().ordinal();
    }
    
    class BlockViewHolder extends RecyclerView.ViewHolder {
        private TextView textSpeaker;
        private TextView textTimestamp;
        private TextView textContent;
        private View speakerIndicator;
        
        public BlockViewHolder(@NonNull View itemView) {
            super(itemView);
            textSpeaker = itemView.findViewById(R.id.text_speaker);
            textTimestamp = itemView.findViewById(R.id.text_timestamp);
            textContent = itemView.findViewById(R.id.text_content);
            speakerIndicator = itemView.findViewById(R.id.speaker_indicator);
        }
        
        public void bind(ContentBlock block) {
            // Отображение спикера
            if (block.getSpeakerName() != null) {
                textSpeaker.setText(block.getSpeakerName());
                textSpeaker.setVisibility(View.VISIBLE);
            } else {
                textSpeaker.setVisibility(View.GONE);
            }
            
            // Цветовой индикатор спикера
            if (block.getSpeakerId() == 0) {
                speakerIndicator.setBackgroundColor(
                    itemView.getContext().getResources().getColor(R.color.speaker_1));
            } else {
                speakerIndicator.setBackgroundColor(
                    itemView.getContext().getResources().getColor(R.color.speaker_2));
            }
            
            // Временная метка
            long seconds = block.getTimestamp() / 1000;
            long mins = seconds / 60;
            long secs = seconds % 60;
            textTimestamp.setText(String.format(Locale.getDefault(), "%02d:%02d", mins, secs));
            
            // Контент в зависимости от типа блока
            if (block instanceof HeadingBlock) {
                HeadingBlock heading = (HeadingBlock) block;
                textContent.setText(heading.getContent());
                textContent.setTextSize(18);
                textContent.setTextStyle(android.graphics.Typeface.BOLD);
            } else if (block instanceof MathBlock) {
                MathBlock math = (MathBlock) block;
                textContent.setText(math.getExpression());
                textContent.setTextColor(
                    itemView.getContext().getResources().getColor(R.color.block_math));
            } else if (block instanceof TextBlock) {
                TextBlock text = (TextBlock) block;
                textContent.setText(text.getText());
                textContent.setTextSize(14);
                textContent.setTextStyle(android.graphics.Typeface.NORMAL);
            } else {
                textContent.setText(block.toMarkdown());
            }
            
            // Индикатор непроверенного блока
            if (!block.isVerified() && !block.getWarnings().isEmpty()) {
                itemView.setAlpha(0.7f);
            } else {
                itemView.setAlpha(1.0f);
            }
        }
    }
}
