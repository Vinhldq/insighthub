"""
InsightHub API — Document chunking
Token-aware chunking với overlap. 2026 best practice: 500-1000 token chunk,
~100 token overlap. Ở đây dùng word-approx (1 token ~ 0.75 word) để tránh
phụ thuộc tiktoken nặng — đủ tốt cho lab.
"""
from app.core.config import get_settings

settings = get_settings()

# 1 token ~ 0.75 word (English approx). Tiếng Việt sai số lớn hơn,
# nhưng đủ dùng cho mục đích teaching.
WORDS_PER_TOKEN = 0.75


def chunk_text(text: str) -> list[str]:
    """Chia text thành các chunk có overlap, theo word-approx của token."""
    words = text.split()
    if not words:
        return []

    chunk_words = int(settings.chunk_size * WORDS_PER_TOKEN)
    overlap_words = int(settings.chunk_overlap * WORDS_PER_TOKEN)
    step = max(chunk_words - overlap_words, 1)

    chunks: list[str] = []
    for start in range(0, len(words), step):
        piece = words[start : start + chunk_words]
        if piece:
            chunks.append(" ".join(piece))
        if start + chunk_words >= len(words):
            break
    return chunks
