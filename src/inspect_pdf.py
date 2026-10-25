from pathlib import Path

import pdfplumber

pdfs = sorted(Path("data").rglob("*.pdf"))
print("PDFs found:", [str(p) for p in pdfs])
if not pdfs:
    raise SystemExit("No PDF under data/")

path = pdfs[0]
print("Inspecting:", path)

with pdfplumber.open(path) as pdf:
    print("pages:", len(pdf.pages))
    table1_page = None
    for i, page in enumerate(pdf.pages):
        text = page.extract_text() or ""
        print(f"page {i + 1}: {len(text)} characters")
        if table1_page is None and "Total Revenue" in text and "Mark-up" in text:
            table1_page = i

    if table1_page is None:
        print("Could not find the Table 1 page by its text.")
    else:
        print("=" * 60)
        print(f"Table 1 appears to be on page {table1_page + 1}. Raw extracted text:")
        print("=" * 60)
        print(pdf.pages[table1_page].extract_text())