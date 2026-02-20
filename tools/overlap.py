#!/usr/bin/env python3
"""
JARPA Plugin Overlap Detector

N-gram-based overlap detection between plugin component files.
Reports pairwise content similarity to identify duplication.

Usage: python3 tools/overlap.py

No external dependencies — Python stdlib only.
"""

import os
import re
import sys
from collections import defaultdict
from pathlib import Path


NGRAM_SIZE = 5
PLUGIN_ROOT = Path(__file__).resolve().parent.parent

# Directories to scan for content files
SCAN_DIRS = ["commands", "agents", "skills", "hooks/scripts"]
EXTENSIONS = {".md", ".sh"}


def normalize_text(text: str) -> str:
    """Normalize text for comparison: lowercase, strip markdown, collapse whitespace."""
    # Remove markdown headers markers
    text = re.sub(r"^#+\s*", "", text, flags=re.MULTILINE)
    # Remove markdown emphasis
    text = re.sub(r"[*_`~]", "", text)
    # Remove markdown links
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    # Remove YAML frontmatter
    text = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.DOTALL)
    # Lowercase
    text = text.lower()
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_ngrams(text: str, n: int = NGRAM_SIZE) -> set:
    """Extract n-gram set from normalized text."""
    words = text.split()
    if len(words) < n:
        return set()
    return {tuple(words[i : i + n]) for i in range(len(words) - n + 1)}


def find_content_files() -> list:
    """Find all content files in plugin directories."""
    files = []
    for scan_dir in SCAN_DIRS:
        dir_path = PLUGIN_ROOT / scan_dir
        if not dir_path.exists():
            continue
        for root, _, filenames in os.walk(dir_path):
            for fname in sorted(filenames):
                fpath = Path(root) / fname
                if fpath.suffix in EXTENSIONS:
                    files.append(fpath)
    return sorted(files)


def main():
    files = find_content_files()
    if not files:
        print("No content files found.", file=sys.stderr)
        sys.exit(1)

    # Extract ngrams per file
    file_ngrams = {}
    file_word_counts = {}
    for fpath in files:
        text = fpath.read_text(errors="replace")
        normalized = normalize_text(text)
        file_ngrams[fpath] = extract_ngrams(normalized)
        file_word_counts[fpath] = len(normalized.split())

    rel = lambda f: str(f.relative_to(PLUGIN_ROOT))

    # Pairwise overlap
    print()
    print("JARPA Plugin Overlap Analysis")
    print("━" * 50)
    print()

    pairs = []
    for i, f1 in enumerate(files):
        for f2 in files[i + 1 :]:
            overlap = file_ngrams[f1] & file_ngrams[f2]
            if overlap:
                pct1 = (
                    len(overlap) / len(file_ngrams[f1]) * 100
                    if file_ngrams[f1]
                    else 0
                )
                pct2 = (
                    len(overlap) / len(file_ngrams[f2]) * 100
                    if file_ngrams[f2]
                    else 0
                )
                # Count unique overlapping words
                overlap_words = set()
                for ngram in overlap:
                    overlap_words.update(ngram)
                pairs.append((rel(f1), rel(f2), len(overlap), pct1, pct2, len(overlap_words)))

    if not pairs:
        print("No overlapping n-grams found between any file pairs.")
        return

    # Sort by overlap count descending
    pairs.sort(key=lambda x: x[2], reverse=True)

    # Print table
    print(f"{'File A':<40} {'File B':<40} {'N-grams':>8} {'%A':>6} {'%B':>6} {'Words':>6}")
    print("─" * 108)
    for f1, f2, count, pct1, pct2, words in pairs:
        # Truncate long paths
        f1_short = f1 if len(f1) <= 38 else "..." + f1[-35:]
        f2_short = f2 if len(f2) <= 38 else "..." + f2[-35:]
        print(f"{f1_short:<40} {f2_short:<40} {count:>8} {pct1:>5.1f}% {pct2:>5.1f}% {words:>6}")

    # Summary
    total_ngrams = sum(len(ng) for ng in file_ngrams.values())
    total_overlap_ngrams = sum(p[2] for p in pairs)
    print()
    print("Summary")
    print("─" * 50)
    print(f"  Files analyzed:          {len(files)}")
    print(f"  Pairs with overlap:      {len(pairs)}")
    print(f"  Total n-grams (all files): {total_ngrams}")
    print(f"  Total overlapping n-grams: {total_overlap_ngrams}")
    print(f"  N-gram size:             {NGRAM_SIZE} words")
    print()


if __name__ == "__main__":
    main()
