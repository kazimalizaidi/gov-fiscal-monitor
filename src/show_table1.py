import sys
import pdfplumber

path = sys.argv[1]
with pdfplumber.open(path) as pdf:
    for i, page in enumerate(pdf.pages):
        text = page.extract_text() or ""
        if "Table 1" in text and "Total Revenue" in text and "Mark-up" in text:
            print(f"--- page {i + 1} ---")
            print(text)
            break
    else:
        print("Table 1 not found")