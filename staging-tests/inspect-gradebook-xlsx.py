"""Read a downloaded fictional XLSX using only Python's standard library."""
import json
import posixpath
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
with zipfile.ZipFile(sys.argv[1]) as archive:
    shared = []
    if 'xl/sharedStrings.xml' in archive.namelist():
        shared = [''.join(x.itertext()) for x in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', ns)]
    rels = {x.attrib['Id']: x.attrib['Target'] for x in ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))}
    result = {}
    for sheet in ET.fromstring(archive.read('xl/workbook.xml')).findall('s:sheets/s:sheet', ns):
        rid = sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']
        target = rels[rid]
        path = target.lstrip('/') if target.startswith('/') else posixpath.normpath('xl/' + target)
        rows, formulas = [], []
        for row in ET.fromstring(archive.read(path)).findall('s:sheetData/s:row', ns):
            values = []
            for cell in row.findall('s:c', ns):
                ref = cell.attrib['r']
                col = 0
                for letter in re.match('[A-Z]+', ref)[0]:
                    col = col * 26 + ord(letter) - ord('A') + 1
                while len(values) < col:
                    values.append(None)
                value = cell.find('s:v', ns)
                kind = cell.attrib.get('t')
                if kind == 'inlineStr':
                    parsed = ''.join(cell.find('s:is', ns).itertext())
                elif value is None or value.text is None:
                    parsed = None
                elif kind == 's':
                    parsed = shared[int(value.text)]
                elif kind in ('str', 'b', 'e'):
                    parsed = value.text
                else:
                    parsed = float(value.text)
                values[col - 1] = parsed
                if cell.find('s:f', ns) is not None:
                    formulas.append(ref)
            rows.append(values)
        result[sheet.attrib['name']] = {'rows': rows, 'formulas': formulas}
    print(json.dumps(result, ensure_ascii=False))
