"""Build an isolated Safari/Chromium QA fixture; never modify the actual game."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--source', type=Path, default=root)
parser.add_argument('--label', default='current')
args = parser.parse_args()
assert re.fullmatch(r'[a-zA-Z0-9-]+', args.label)
project = root / 'artifacts' / f'browser-benchmark-{args.label}'
output = root / 'artifacts' / f'browser-benchmark-{args.label}-web'
project.mkdir(parents=True, exist_ok=True)
output.mkdir(parents=True, exist_ok=True)
for name in ['scripts', 'scenes', 'assets', 'web']:
    shutil.copytree(args.source / name, project / name, dirs_exist_ok=True)
for name in ['project.godot', 'export_presets.cfg', 'icon.svg']:
    shutil.copy2(args.source / name, project / name)
main = project / 'scripts/main.gd'
source = main.read_text()
source, count = re.subn(r'\ttest_mode = .*', '\ttest_mode = true', source, count=1)
assert count == 1
main.write_text(source)
shutil.copy2(root / 'tests/browser_performance_scene.gd', project / 'qa.gd')
(project / 'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="BrowserQA" type="Node"]\nscript = ExtResource("1")\n')
config = (project / 'project.godot').read_text().replace('res://scenes/main.tscn', 'res://qa.tscn')
(project / 'project.godot').write_text(config)
preset = project / 'export_presets.cfg'
preset.write_text(preset.read_text().replace('progressive_web_app/enabled=true', 'progressive_web_app/enabled=false'))
for command in [['--editor', '--import', '--quit'], ['--export-release', 'Web', str(output / 'index.html')]]:
    run = subprocess.run([args.godot, '--headless', '--path', str(project), *command], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (output / 'export.log').write_text(run.stdout)
    if run.returncode or re.search(r'(SCRIPT ERROR:|ERROR:|Parse Error:)', run.stdout):
        raise RuntimeError(run.stdout)
print(output / 'index.html')
