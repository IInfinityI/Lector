package com.example.lector.plugin;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Простая событийная шина ядра. Плагины подписываются на события
 * жизненного цикла записи и редактирования, не зная о реализации ядра.
 */
public class EventBus {

    public enum Event {
        RECORDING_STARTED,
        RECORDING_STOPPED,
        TRANSCRIPTION_RECEIVED,
        BLOCK_ADDED,
        LECTURE_SAVED,
        LECTURE_LOADED
    }

    public interface Listener {
        void onEvent(Event event, Object payload);
    }

    private final Map<Event, List<Listener>> listeners = new HashMap<>();

    public void subscribe(Event event, Listener listener) {
        List<Listener> list = listeners.get(event);
        if (list == null) {
            list = new ArrayList<>();
            listeners.put(event, list);
        }
        list.add(listener);
    }

    public void publish(Event event, Object payload) {
        List<Listener> list = listeners.get(event);
        if (list == null) return;
        for (Listener l : new ArrayList<>(list)) {
            try {
                l.onEvent(event, payload);
            } catch (Exception ignored) {
                // Плагин не должен ронять ядро
            }
        }
    }
}
