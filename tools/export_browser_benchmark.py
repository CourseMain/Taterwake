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
parser.add_argument('--fixture', choices=['performance', 'climate', 'mobile', 'feel', 'playthrough', 'surfaces'], default='performance')
parser.add_argument('--feel-stage-timings', action='store_true', help='Instrument HUD/touch stages only in the disposable feel fixture')
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
if args.fixture == 'feel':
    # The frozen baseline predates save timing. Instrument only its disposable
    # copy, wrapping the identical write implementation without changing it.
    state = project / 'scripts/game_state.gd'
    source = state.read_text()
    if 'var last_save_ms:' not in source:
        signature = 'func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:'
        assert source.count(signature) == 1
        wrapper = ('var last_save_ms: float = 0.0\n\n' + signature + '\n'
                   '\tvar started: int = Time.get_ticks_usec()\n'
                   '\tvar saved: bool = _feel_write_save(path)\n'
                   '\tlast_save_ms = (Time.get_ticks_usec() - started) / 1000.0\n'
                   '\treturn saved\n\n'
                   'func _feel_write_save(path: String = DEFAULT_SAVE_PATH) -> bool:')
        state.write_text(source.replace(signature, wrapper))
    if args.feel_stage_timings:
        def instrument(filename, names):
            target = project / 'scripts' / filename
            text = target.read_text()
            for name in names:
                pattern = rf'^func {re.escape(name)}\(([^\n]*)\) -> (\w+):\n'
                match = re.search(pattern, text, re.MULTILINE)
                if not match:
                    continue
                parameters = match.group(1)
                result_type = match.group(2)
                arguments = ', '.join(part.split(':', 1)[0].strip() for part in parameters.split(',') if part.strip())
                call = (f'\t_feel_original_{name}({arguments})\n' if result_type == 'void'
                        else f'\tvar feel_result: {result_type} = _feel_original_{name}({arguments})\n')
                wrapper = (f'func {name}({parameters}) -> {result_type}:\n'
                           '\tvar feel_started: int = Time.get_ticks_usec()\n'
                           + call + f'\t_feel_record_stage("{name}", feel_started)\n'
                           + ('\treturn feel_result\n' if result_type != 'void' else '')
                           + f'\nfunc _feel_original_{name}({parameters}) -> {result_type}:\n')
                text = text[:match.start()] + wrapper + text[match.end():]
            if filename == 'game_hud.gd':
                marker = '\tportrait.show_person("nell")'
                assert text.count(marker) == 1
                text = text.replace(marker, '\tvar feel_portrait_started: int = Time.get_ticks_usec()\n'
                                    + marker + '\n\t_feel_record_stage("portrait.show_person", feel_portrait_started)')
            text += ('\nvar _feel_profile: Dictionary = {}\n'
                     'func _feel_record_stage(stage: String, started: int) -> void:\n'
                     '\tvar elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0\n'
                     '\tvar stats: Dictionary = _feel_profile.get(stage, {"calls": 0, "total_ms": 0.0, "max_ms": 0.0})\n'
                     '\tstats.calls += 1\n'
                     '\tstats.total_ms += elapsed_ms\n'
                     '\tstats.max_ms = maxf(stats.max_ms, elapsed_ms)\n'
                     '\t_feel_profile[stage] = stats\n')
            target.write_text(text)
        instrument('game_hud.gd', ['show_panel', '_build_winter', '_account_row', '_build_diversification', '_build_loss_cards', '_paper_typography', '_refresh_accounts', '_refresh_panel', '_layout_purchase', '_begin_panel_entrance'])
        instrument('touch_controls.gd', ['fit_modal', 'adapt', 'resize'])
        instrument('farm_world.gd', ['update_plots', 'set_calendar', '_apply_season', 'set_climate', '_set_winter_cover'])
        instrument('farm_visuals.gd', ['sync_state', 'set_winter', 'set_snow_opacity'])
        instrument('main.gd', ['_on_state_changed'])
shutil.copy2(root / f'tests/browser_{args.fixture}_scene.gd', project / 'qa.gd')
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
