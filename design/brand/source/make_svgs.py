import sys, os
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
OUT=sys.argv[1]
f=TTFont(os.path.join(os.path.dirname(__file__),'font/Fredoka-var.ttf'))
f=instancer.instantiateVariableFont(f,{'wght':700,'wdth':100})
gs=f.getGlyphSet(); cmap=f.getBestCmap(); upem=f['head'].unitsPerEm; s=300/upem
def path(ch):
    pen=SVGPathPen(gs, ntos=lambda v: ('%.1f'%v).rstrip('0').rstrip('.'))
    gs[cmap[ord(ch)]].draw(TransformPen(pen,(s,0,0,-s,0,0)))
    return pen.getCommands()
G={c:path(c) for c in 'PEL'}
FOOT='<rect x="121" y="-44" width="106" height="46" rx="10.1"/>'
def glyph(c): return f'<path d="{G[c]}"/>'
COLS=['#FF3DA5','#FF7A00','#2FB344','#3D5AFE']
def sticker(p, tf, shadow_color, shadow_op):
    """tf: list of 4 transforms (P,E,E,L). Returns defs+body for a peeling PEEL sticker."""
    letters='PEEL'
    def g(i, inner_attrs, extra=''):
        clip=f' clip-path="url(#{p}-keep)"' if i==3 else ''
        foot=FOOT if i==3 else ''
        return f'<g transform="{tf[i]}"{clip}{inner_attrs}>{glyph(letters[i])}{foot}</g>'
    defs=f'''<clipPath id="{p}-keep"><polygon points="-1936.4,2082.2 2306.2,-2160.4 184.9,-4281.7 -4057.7,-39.1"/></clipPath>
<clipPath id="{p}-away"><polygon points="-1936.4,2082.2 2306.2,-2160.4 4427.6,-39.1 184.9,4203.6"/></clipPath>
<linearGradient id="{p}-flap" gradientUnits="userSpaceOnUse" x1="184.9" y1="-39.1" x2="245.9" y2="21.9"><stop offset="0" stop-color="#D9DAE2"/><stop offset="0.18" stop-color="#FFFFFF"/><stop offset="0.6" stop-color="#F1F1F5"/><stop offset="1" stop-color="#C9CBD6"/></linearGradient>
<filter id="{p}-sh" x="-20%" y="-30%" width="140%" height="160%"><feDropShadow dx="0" dy="15.4" stdDeviation="19.8" flood-color="{shadow_color}" flood-opacity="{shadow_op}"/></filter>
<filter id="{p}-fs" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="13.2"/></filter>'''
    edge='<g stroke-width="54" stroke-linejoin="round">'
    sil=f'<g filter="url(#{p}-sh)" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="54" stroke-linejoin="round">'+''.join(g(i,'') for i in range(4))+'</g>'
    col='<g stroke-width="10" stroke-linejoin="round">'+''.join(g(i,f' fill="{COLS[i]}" stroke="{COLS[i]}"') for i in range(4))+'</g>'
    flapsrc=glyph('L')+FOOT
    R='matrix(0 -1 -1 0 145.8241 145.8241)'
    flap=(f'<g transform="{tf[3]}" stroke-width="54" stroke-linejoin="round">'
          f'<g opacity="0.45" transform="translate(-6.6 -8.8)" filter="url(#{p}-fs)"><g transform="{R}"><g clip-path="url(#{p}-away)" fill="#000000" stroke="#000000">{flapsrc}</g></g></g>'
          f'<g transform="{R}"><g clip-path="url(#{p}-away)" fill="url(#{p}-flap)" stroke="url(#{p}-flap)">{flapsrc}</g></g></g>')
    return defs, sil+col+flap
def silhouette(p, tf):
    """Monochrome: white sticker shape with the letters cut out, peel included."""
    letters='PEEL'
    def g(i, attrs):
        clip=f' clip-path="url(#{p}-keep)"' if i==3 else ''
        return f'<g transform="{tf[i]}"{clip}{attrs}>{glyph(letters[i])}{FOOT if i==3 else ""}</g>'
    R='matrix(0 -1 -1 0 145.8241 145.8241)'
    defs=f'''<clipPath id="{p}-keep"><polygon points="-1936.4,2082.2 2306.2,-2160.4 184.9,-4281.7 -4057.7,-39.1"/></clipPath>
<clipPath id="{p}-away"><polygon points="-1936.4,2082.2 2306.2,-2160.4 4427.6,-39.1 184.9,4203.6"/></clipPath>
<mask id="{p}-m" maskUnits="userSpaceOnUse" x="-2000" y="-2000" width="4000" height="4000"><rect x="-2000" y="-2000" width="4000" height="4000" fill="#fff"/><g fill="#000" stroke="#000" stroke-width="10" stroke-linejoin="round">{"".join(g(i,"") for i in range(4))}</g></mask>'''
    body=(f'<g mask="url(#{p}-m)" fill="#fff" stroke="#fff" stroke-width="54" stroke-linejoin="round">'+''.join(g(i,'') for i in range(4))+'</g>'
          f'<g transform="{tf[3]}" fill="#fff" stroke="#fff" stroke-width="54" stroke-linejoin="round" opacity="0.7"><g transform="{R}"><g clip-path="url(#{p}-away)">{glyph("L")}{FOOT}</g></g></g>')
    return defs, body
ST=['translate(-10 0) rotate(-5 92.5 -102.5)','translate(152 -6) rotate(4 94 -102.5)','translate(-4.5 239.6) rotate(-4 94 -102.5)','translate(155.5 233.6) rotate(4 91 -102.5)']
WM=['translate(-10 0) rotate(-6 92.5 -102.5)','translate(150 -10) rotate(4 94 -102.5)','translate(312 6) rotate(-3 94 -102.5)','translate(470 -4) rotate(5 91 -102.5)']
BG=tuple(os.environ.get('PEEL_BG','#2C2C36,#18181E').split(','))
ICON_T='translate(302.2 504.3) scale(1.2879)'
def adaptive_t(k):  # scale icon composition by k about the centre
    return f'translate({512-512*k:.1f} {512-512*k:.1f}) scale({k}) {ICON_T}'
def svg(w,h,defs,body,bg=None,vb=None,rx=None):
    vb=vb or f'0 0 {w} {h}'
    back=''
    if bg:
        top,bot=(bg if isinstance(bg,tuple) else (bg,bg))
        defs+=f'<linearGradient id="bgG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>'
        back=f'<rect width="{w}" height="{h}"{f" rx=\"{rx}\"" if rx else ""} fill="url(#bgG)"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb}"><defs>{defs}</defs>{back}{body}</svg>\n'
os.makedirs(OUT,exist_ok=True)
d,b=sticker('i',ST,'#000000',0.5)
open(f'{OUT}/icon-1024.svg','w').write(svg(1024,1024,d,f'<g transform="{ICON_T}">{b}</g>',bg=BG))
open(f'{OUT}/icon-1024-rounded.svg','w').write(svg(1024,1024,d,f'<g transform="{ICON_T}">{b}</g>',bg=BG,rx=229))
open(f'{OUT}/adaptive-foreground.svg','w').write(svg(1024,1024,d,f'<g transform="{adaptive_t(0.66)}">{b}</g>'))
open(f'{OUT}/adaptive-background.svg','w').write(svg(1024,1024,'','',bg=BG))
md,mb=silhouette('m',ST)
open(f'{OUT}/adaptive-monochrome.svg','w').write(svg(1024,1024,md,f'<g transform="{adaptive_t(0.66)}">{mb}</g>'))
wd,wb=sticker('w',WM,'#3A2A1A',0.16)
open(f'{OUT}/wordmark.svg','w').write(svg(830,480,wd,wb,vb='-70 -350 830 480'))
print('ok', {c:len(v) for c,v in G.items()})
