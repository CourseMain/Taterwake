#!/usr/bin/env python3
"""Build the original potato currency glyph. Dev dependency: fonttools.

The tiny bundled outline font avoids OS-dependent emoji and oversized emoji
line metrics. It contains U+E000 and drawn arrows; normal text uses the two UI faces.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.reverseContourPen import ReverseContourPen


def contour(pen, points, reverse=False):
    recording = RecordingPen()
    recording.moveTo(points[0])
    for control, endpoint in zip(points[1::2], points[2::2]):
        recording.qCurveTo(control, endpoint)
    recording.closePath()
    recording.replay(ReverseContourPen(pen) if reverse else pen)


def oval(pen, x, y, rx, ry, reverse=False):
    contour(pen, [(x, y + ry), (x + rx, y + ry), (x + rx, y),
                  (x + rx, y - ry), (x, y - ry),
                  (x - rx, y - ry), (x - rx, y),
                  (x - rx, y + ry), (x, y + ry)], reverse=reverse)


pen = TTGlyphPen(None)
# A solid tuber, two eye counters and a small curved highlight. The same
# monochrome glyph follows the amount's font colour on every surface.
contour(pen, [(335, 715), (495, 765), (605, 645), (680, 565), (661, 450),
              (646, 335), (698, 226), (762, 71), (624, -24),
              (512, -105), (354, -65), (198, -34), (132, 104),
              (78, 223), (138, 352), (190, 455), (191, 546),
              (199, 665), (335, 715)])
for eye in [(326, 330, 34, 43), (499, 330, 34, 43)]:
    oval(pen, *eye, reverse=True)
contour(pen, [(265, 526), (260, 628), (365, 652), (409, 665), (420, 632),
              (428, 604), (384, 602), (308, 588), (311, 524),
              (290, 502), (265, 526)], reverse=True)
font = FontBuilder(1000, isTTF=True)
arrow_points = [(100,340),(510,340),(375,475),(425,525),(650,300),(425,75),(375,125),(510,260),(100,260)]
glyphs = {".notdef": TTGlyphPen(None).glyph(), "spudion": pen.glyph()}
for name, turn in [("arrow", 0), ("up", 1), ("down", -1)]:
    arrow = TTGlyphPen(None)
    points = [(x, y) if turn == 0 else (375 - turn * (y - 300), 300 + turn * (x - 375)) for x, y in arrow_points]
    arrow.moveTo(points[0])
    for point in points[1:]:
        arrow.lineTo(point)
    arrow.closePath()
    glyphs[name] = arrow.glyph()
font.setupGlyphOrder(list(glyphs))
font.setupCharacterMap({0xE000: "spudion", 0x2192: "arrow", 0x2191: "up", 0x2193: "down"})
font.setupGlyf(glyphs)
font.setupHorizontalMetrics({name: (800, 80) if name == "spudion" else (750, 100) for name in glyphs})
font.setupHorizontalHeader(ascent=800, descent=-200, lineGap=0)
font.setupNameTable({"familyName": "Taterland Spudion", "styleName": "Regular",
                    "uniqueFontIdentifier": "TaterlandSpudion-2.0",
                    "fullName": "Taterland Spudion Regular", "psName": "TaterlandSpudion-Regular",
                    "version": "Version 2.0", "copyright": "Copyright 2026 Taterland contributors."})
font.setupOS2(sTypoAscender=800, sTypoDescender=-200, sTypoLineGap=0,
             usWinAscent=800, usWinDescent=200)
font.setupPost()
font.setupMaxp()
font.font["head"].created = font.font["head"].modified = 3873312000
font.font.recalcTimestamp = False
target = Path(__file__).resolve().parents[1] / "assets/fonts/SpudionGlyph.ttf"
font.save(target)
print(target)
