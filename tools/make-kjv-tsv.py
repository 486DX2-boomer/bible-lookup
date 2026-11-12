"""Generate kjv.tsv from eBible.org's public-domain KJV.

Source: https://ebible.org/Scriptures/eng-kjv_vpl.zip (extract
eng-kjv_vpl.txt).  Usage:

    python make-kjv-tsv.py eng-kjv_vpl.txt ../kjv.tsv

Output is UTF-8, LF line endings, one verse per line:

    book<TAB>chapter<TAB>verse<TAB>text

Apocrypha books are dropped, italics brackets ("[was]") are removed
keeping the words, and paragraph marks are removed.
"""

import re
import sys

BOOKS = [
    ("GEN", "Genesis"), ("EXO", "Exodus"), ("LEV", "Leviticus"),
    ("NUM", "Numbers"), ("DEU", "Deuteronomy"), ("JOS", "Joshua"),
    ("JDG", "Judges"), ("RUT", "Ruth"), ("1SA", "1 Samuel"),
    ("2SA", "2 Samuel"), ("1KI", "1 Kings"), ("2KI", "2 Kings"),
    ("1CH", "1 Chronicles"), ("2CH", "2 Chronicles"), ("EZR", "Ezra"),
    ("NEH", "Nehemiah"), ("EST", "Esther"), ("JOB", "Job"),
    ("PSA", "Psalms"), ("PRO", "Proverbs"), ("ECC", "Ecclesiastes"),
    ("SOL", "Song of Solomon"), ("ISA", "Isaiah"), ("JER", "Jeremiah"),
    ("LAM", "Lamentations"), ("EZE", "Ezekiel"), ("DAN", "Daniel"),
    ("HOS", "Hosea"), ("JOE", "Joel"), ("AMO", "Amos"),
    ("OBA", "Obadiah"), ("JON", "Jonah"), ("MIC", "Micah"),
    ("NAH", "Nahum"), ("HAB", "Habakkuk"), ("ZEP", "Zephaniah"),
    ("HAG", "Haggai"), ("ZEC", "Zechariah"), ("MAL", "Malachi"),
    ("MAT", "Matthew"), ("MAR", "Mark"), ("LUK", "Luke"),
    ("JOH", "John"), ("ACT", "Acts"), ("ROM", "Romans"),
    ("1CO", "1 Corinthians"), ("2CO", "2 Corinthians"),
    ("GAL", "Galatians"), ("EPH", "Ephesians"), ("PHI", "Philippians"),
    ("COL", "Colossians"), ("1TH", "1 Thessalonians"),
    ("2TH", "2 Thessalonians"), ("1TI", "1 Timothy"),
    ("2TI", "2 Timothy"), ("TIT", "Titus"), ("PHM", "Philemon"),
    ("HEB", "Hebrews"), ("JAM", "James"), ("1PE", "1 Peter"),
    ("2PE", "2 Peter"), ("1JO", "1 John"), ("2JO", "2 John"),
    ("3JO", "3 John"), ("JUD", "Jude"), ("REV", "Revelation"),
]
NAMES = dict(BOOKS)
LINE_RE = re.compile(r"^(\w{3}) (\d+):(\d+) (.*)$")

# Expected totals for the 66-book Protestant canon in KJV versification.
EXPECTED_BOOKS, EXPECTED_CHAPTERS, EXPECTED_VERSES = 66, 1189, 31102


def clean(text):
    text = text.replace("¶", "")
    text = text.replace("[", "").replace("]", "")
    return " ".join(text.split())


def main(src, dest):
    rows = []
    with open(src, encoding="utf-8") as f:
        for line in f:
            m = LINE_RE.match(line.rstrip("\n"))
            if not m:
                sys.exit("Unparseable line: %r" % line)
            code, ch, v, text = m.groups()
            if code in NAMES:
                rows.append((NAMES[code], int(ch), int(v), clean(text)))

    books = {r[0] for r in rows}
    chapters = {(r[0], r[1]) for r in rows}
    keys = [(r[0], r[1], r[2]) for r in rows]
    problems = []
    if len(books) != EXPECTED_BOOKS:
        problems.append("books: %d" % len(books))
    if len(chapters) != EXPECTED_CHAPTERS:
        problems.append("chapters: %d" % len(chapters))
    if len(rows) != EXPECTED_VERSES:
        problems.append("verses: %d" % len(rows))
    if len(set(keys)) != len(keys):
        problems.append("duplicate references")
    if any(not r[3] or "\t" in r[3] for r in rows):
        problems.append("empty text or embedded tab")
    if [name for _, name in BOOKS] !=list(dict.fromkeys(r[0] for r in rows)):
        problems.append("books out of canonical order")
    if problems:
        sys.exit("Validation failed: " + ", ".join(problems))

    with open(dest, "w", encoding="utf-8", newline="\n") as out:
        for book, ch, v, text in rows:
            out.write("%s\t%d\t%d\t%s\n" % (book, ch, v, text))
    print("Wrote %d verses, %d chapters, %d books to %s"
          % (len(rows), len(chapters), len(books), dest))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
