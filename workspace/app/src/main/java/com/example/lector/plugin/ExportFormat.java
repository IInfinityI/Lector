package com.example.lector.plugin;

/**
 * Описание формата экспорта, который может предоставить мод.
 * Ядро знает только про MARKDOWN; любой другой формат добавляется плагином.
 */
public class ExportFormat {

    private final String id;        // "pdf", "docx", "html"...
    private final String displayName; // "PDF-документ"
    private final String fileExtension;  // ".pdf"

    public ExportFormat(String id, String displayName, String fileExtension) {
        this.id = id;
        this.displayName = displayName;
        this.fileExtension = fileExtension.startsWith(".") ? fileExtension : "." + fileExtension;
    }

    public String getId() { return id; }

    public String getDisplayName() { return displayName; }

    /** Включая точку, например ".pdf". */
    public String getFileExtension() { return fileExtension; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ExportFormat)) return false;
        return id.equals(((ExportFormat) o).id);
    }

    @Override
    public int hashCode() { return id.hashCode(); }
}
