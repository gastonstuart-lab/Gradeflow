"""Validate the workbook downloaded through the historical interface."""
from xml.etree import ElementTree
from zipfile import ZipFile

with ZipFile("evidence/historical.xlsx") as workbook:
    assert workbook.testzip() is None
    namespace = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
    sheets = ElementTree.fromstring(workbook.read("xl/workbook.xml"))
    assert any(sheet.get("name") == "Periods" for sheet in sheets.iter(f"{namespace}sheet"))
    strings = ElementTree.fromstring(workbook.read("xl/sharedStrings.xml"))
    shared = ["".join(item.itertext()) for item in strings]
    sheet_rows = []
    for path in workbook.namelist():
        if not path.startswith("xl/worksheets/sheet") or not path.endswith(".xml"):
            continue
        sheet = ElementTree.fromstring(workbook.read(path))
        for row in sheet.iter(f"{namespace}row"):
            values = []
            for cell in row:
                value = cell.findtext(f"{namespace}v")
                values.append(shared[int(value)] if cell.get("t") == "s" else value)
            sheet_rows.append(values)
    assert any("preview-period-1" in row and "November" in row for row in sheet_rows)
    alex = next(row for row in sheet_rows if "S01" in row and "Alex Example" in row)
    assert float(alex[-2]) == 88, alex
    assert sum(1 for row in sheet_rows if row and row[0] in {f"S{i:02}" for i in range(1, 13)}) == 12

print("PASS historical Excel export: November metadata, all 12 students, and Alex's archived exam score of 88")
