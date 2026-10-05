"""Export the two installed UI modules as a reusable native Roblox model."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
document = ET.Element('roblox', version='4')
for index, name in enumerate(('ProgressView', 'TerminalUI')):
    item = ET.SubElement(document, 'Item', {'class': 'ModuleScript', 'referent': f'RBX{index}'})
    props = ET.SubElement(item, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = name
    ET.SubElement(props, 'ProtectedString', name='Source').text = (root / 'src' / f'{name}.luau').read_text(encoding='utf-8')
destination = root / 'output/progress-redesign-20261001/Progress UI Modules.rbxmx'
ET.ElementTree(document).write(destination, encoding='utf-8', xml_declaration=True)
saved = ET.parse(destination).getroot()
for item in saved.findall('Item'):
    props = item.find('Properties')
    name = props.find("string[@name='Name']").text
    assert props.find("ProtectedString[@name='Source']").text == (root / 'src' / f'{name}.luau').read_text(encoding='utf-8')
print(f'Verified native module export: {destination}')
