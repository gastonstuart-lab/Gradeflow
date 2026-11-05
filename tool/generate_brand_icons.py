"""Export the code-native InstructOS layer mark for browser/PWA icons."""
from pathlib import Path
from PIL import Image, ImageDraw

def icon(size, maskable=False):
    scale=4
    edge=size*scale
    image=Image.new('RGBA',(edge,edge))
    draw=ImageDraw.Draw(image)
    for y in range(edge):
        t=y/(edge-1)
        draw.line((0,y,edge,y),fill=tuple(round(a+(b-a)*t) for a,b in zip((23,59,99),(24,127,121)))+(255,))
    if not maskable:
        mask=Image.new('L',(edge,edge));ImageDraw.Draw(mask).rounded_rectangle((0,0,edge,edge),radius=edge*19/64,fill=255);image.putalpha(mask)
    def point(x,y):return (round(x*edge/64),round(y*edge/64))
    draw.polygon([point(17,25),point(32,14),point(47,25),point(32,36)],fill='white')
    for y in (32,39):draw.line([point(17,y),point(32,y+11),point(47,y)],fill='white',width=round(edge*3/64),joint='curve')
    return image.resize((size,size),Image.Resampling.LANCZOS)

root=Path(__file__).resolve().parents[1]/'web'
for size in (192,512):
    icon(size).save(root/'icons'/f'Icon-{size}.png')
    icon(size,True).save(root/'icons'/f'Icon-maskable-{size}.png')
icon(32).save(root/'favicon.png')
