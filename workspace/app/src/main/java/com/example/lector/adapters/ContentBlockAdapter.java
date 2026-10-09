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

    /** Клик по блоку — запрос перемотки аудио на таймкод блока (мс). */
    public interface OnBlockSeekListener {
        void onSeekTo(long timestampMs);
    }

    private List<ContentBlock> blocks;
    private SimpleDateFormat timeFormat;
    private OnBlockSeekListener seekListener;
    private long playingTimestampMs = -1; // текущая позиция воспроизведения, -1 — пауза

    public ContentBlockAdapter(List<ContentBlock> blocks) {
        this.blocks = blocks;
        this.timeFormat = new SimpleDateFormat("mm:ss", Locale.getDefault());
    }

    public void setOnBlockSeekListener(OnBlockSeekListener listener) {
        this.seekListener = listener;
    }

    /** Подсветка активного блока во время воспроизведения. */
    public void setPlayingTimestamp(long ms) {
        if (this.playingTimestampMs == ms) return;
        this.playingTimestampMs = ms;
        notifyItemRangeChanged(0, blocks.size());
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
            bind(block, getAdapterPosition());
        }

        public void bind(ContentBlock block, int position) {
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
                textContent.setText(heading.getText());
                textContent.setTextSize(18);
                textContent.setTypeface(null, android.graphics.Typeface.BOLD);
            } else if (block instanceof MathBlock) {
                MathBlock math = (MathBlock) block;
                textContent.setText(math.getPlainExpression());
                textContent.setTextColor(
                    itemView.getContext().getResources().getColor(R.color.block_math));
            } else if (block instanceof com.example.lector.plugin.builtin.HighlightBlock) {
                com.example.lector.plugin.builtin.HighlightBlock hl =
                    (com.example.lector.plugin.builtin.HighlightBlock) block;
                textContent.setText(hl.getText());
                textContent.setTypeface(null, android.graphics.Typeface.BOLD);
                textContent.setBackgroundColor(hl.parseColor());
            } else if (block instanceof TextBlock) {
                TextBlock text = (TextBlock) block;
                textContent.setText(text.getText());
                textContent.setTextSize(14);
                textContent.setTypeface(null, android.graphics.Typeface.NORMAL);
            } else {
                textContent.setText(block.toMarkdown());
            }
            
            // Индикатор непроверенного блока
            if (!block.isVerified() && !block.getWarnings().isEmpty()) {
                itemView.setAlpha(0.7f);
            } else {
                itemView.setAlpha(1.0f);
            }

            // Синхронизация аудио↔текст: клик по блоку перематывает аудио
            itemView.setOnClickListener(v -> {
                if (seekListener != null) {
                    seekListener.onSeekTo(block.getTimestamp());
                }
            });
            textTimestamp.setOnClickListener(v -> {
                if (seekListener != null) {
                    seekListener.onSeekTo(block.getTimestamp());
                }
            });

            // Активный блок при воспроизведении — визуально выделен
            boolean active = isActiveBlock(position, block.getTimestamp());
            itemView.setSelected(active);
            float baseAlpha = (!block.isVerified() && !block.getWarnings().isEmpty()) ? 0.7f : 1.0f;
            itemView.setAlpha(active ? baseAlpha : baseAlpha * 0.95f);
        }
    }

    /** Блок активен, если это ближайший предшествующий текущей позиции воспроизведения блок. */
    private boolean isActiveBlock(int pos, long ts) {
        if (playingTimestampMs < 0) return false;
        if (ts > playingTimestampMs) return false;
        // следующий блок с ненулевым таймкодом должен начинаться позже текущей позиции
        for (int i = pos + 1; i < blocks.size(); i++) {
            long next = blocks.get(i).getTimestamp();
            if (next > 0) {
                return playingTimestampMs < next;
            }
        }
        return true; // последний блок
    }
}
