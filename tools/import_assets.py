"""Compose the game's original room using an owner's licensed LimeZu pack.

Raw paid artwork stays ignored by Git. Run with --pack PATH on another machine.
The source also runs with a simple original fallback when this pack is absent.
"""
from pathlib import Path
import argparse, shutil, math, wave, struct
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--pack', type=Path, default=Path.home()/'Downloads'/'moderninteriors-win')
args = p.parse_args()
out = ROOT/'assets'/'licensed'
out.mkdir(parents=True, exist_ok=True)
base = args.pack/'1_Interiors'/'16x16'/'Theme_Sorter'
kitchen = Image.open(base/'12_Kitchen_16x16.png').convert('RGBA')
generic = Image.open(base/'1_Generic_16x16.png').convert('RGBA')
living = Image.open(base/'2_LivingRoom_16x16.png').convert('RGBA')
room = Image.new('RGBA', (256,192), '#654855')
d = ImageDraw.Draw(room)
# Original architecture, tiled wood floor, picture windows, and afternoon light.
d.rectangle((8,8,247,182), fill='#f3d9b1')
for y in range(48,183,8):
    for x in range(8,248,32):
        x += 16 if (y//8)%2 else 0
        if x >= 248: continue
        d.rectangle((x,y,min(x+30,247),y+6), fill=['#c89970','#cfa17a','#d8af87'][(x+y)//8%3])
d.rectangle((8,43,247,49), fill='#886652')
d.rectangle((8,40,247,42), fill='#a7ad7a')
for x in (20,68,188):
    d.rectangle((x-2,13,x+35,39), fill='#806353')
    d.rectangle((x,15,x+33,36), fill='#c7dada')
    d.rectangle((x+1,16,x+31,29), fill='#93b5ac')
    d.rectangle((x+3,18,x+15,25), fill='#ecf2c7')
    d.line((x+17,15,x+17,37), fill='#f5e4bf',width=2)
    d.line((x,28,x+33,28), fill='#f5e4bf',width=2)
    d.polygon([(x+4,50),(x+34,50),(x+55,95),(x+27,95)], fill='#dfbc86')
d.rectangle((112,13,165,34), fill='#68514d')
d.text((119,18), 'CAFE', fill='#f9d58b')
d.text((118,26), 'SHIFT', fill='#e6bda2')
# All placements are deliberately composed for this game, not a sample room.
def prop(sheet, box, xy):
    tile=sheet.crop(box); room.alpha_composite(tile, xy)
for x in range(112,225,32):
    prop(kitchen,(192,272,224,304),(x,82))
prop(kitchen,(128,112,160,144),(126,59))
prop(kitchen,(192,112,224,144),(184,59))
prop(kitchen,(144,128,176,144),(160,71))
for xy in ((22,88),(65,131),(188,145)):
    prop(generic,(0,64,64,112),xy)
for xy in ((11,79),(80,76),(12,122),(130,128),(174,135),(225,130)):
    prop(generic,(64,176,80,208),xy)
for xy in ((8,26),(225,28),(8,151),(232,151)):
    prop(living,(160,0,176,32),xy)
prop(generic,(144,64,208,112),(129,124))
room.save(out/'cafe.png')
chars=args.pack/'2_Characters'/'Old'/'Single_Characters_Legacy'/'16x16'
for name in ('Amelia','Adam','Alex','Bob','Lucy','Ash'):
    for action in ('idle_anim','run'):
        src=chars/f'{name}_{action}_16x16.png'
        if src.exists(): shutil.copyfile(src,out/f'{name}_{action}.png')
shutil.copyfile(args.pack/'LICENSE.txt',out/'LICENSE.txt')
# Original pixel icons: simple hand-authored geometry, no image generation.
icons=ROOT/'assets'/'original'; icons.mkdir(parents=True,exist_ok=True)
for name, tint in [('espresso','#674239'),('latte','#c69361'),('coldbrew','#734e4a'),('chai','#cd9e51'),('matcha','#80965e'),('croissant','#d98f43'),('toastie','#dba965'),('brownie','#69433f'),('cookie','#d2a276')]:
    im=Image.new('RGBA',(32,32)); q=ImageDraw.Draw(im)
    q.ellipse((2,25,29,29),fill='#e4cbb0')
    if name in ('croissant','toastie','brownie','cookie'):
        q.rectangle((4,13,27,24),fill='#8d583e')
        q.rectangle((5,11,26,21),fill=tint)
        for x in (9,17,23): q.rectangle((x,13,x+2,15),fill='#5a3e37')
        q.line((8,11,24,11),fill='#f7cf83',width=2)
    else:
        q.rectangle((6,11,23,25),fill='#fff0d0')
        q.rectangle((8,9,21,12),fill=tint)
        q.rectangle((23,13,27,20),outline='#fff0d0',width=2)
        q.rectangle((7,23,22,25),fill='#d7c0a3')
        q.line((10,7,10,4),fill='#d1b7a1');q.line((17,6,17,2),fill='#d1b7a1')
    im.save(icons/f'{name}.png')
# Authored short sine chimes stored as samples for Godot Web compatibility.
for name,notes in [('tap',[660]),('order',[523,659,784]),('done',[784,988,1047]),('error',[220,185])]:
    samples=[]
    for freq in notes:
        for i in range(3600):
            a=math.sin(2*math.pi*freq*i/24000)*math.exp(-i/1100)*0.17
            samples.append(struct.pack('<h',int(a*32767)))
    with wave.open(str(icons/f'{name}.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(24000);w.writeframes(b''.join(samples))
print('Composed licensed cafe, animated characters, 9 original menu icons and 4 chimes.')
