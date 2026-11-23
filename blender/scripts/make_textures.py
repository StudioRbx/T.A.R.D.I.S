"""Génère les textures 2D du TARDIS (enseigne, plaque, badge) avec Pillow.

Lancement : python3 blender/scripts/make_textures.py
Sortie    : blender/textures/*.png (chargées puis empaquetées par build_tardis.py)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.normpath(os.path.join(ICI, "..", "textures"))
os.makedirs(SORTIE, exist_ok=True)

GRAS = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
NORMAL = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
CREME = (246, 236, 214)


def police(chemin, taille):
    return ImageFont.truetype(chemin, taille)


def texte_centre(d, cx, cy, txt, f, fill, etirement=None):
    l, t, r, b = d.textbbox((0, 0), txt, font=f)
    d.text((cx - (r - l) / 2 - l, cy - (b - t) / 2 - t), txt, font=f, fill=fill)


def texte_etroit(img, cx, cy, txt, f, fill, sx=0.78):
    """Dessine un texte condensé horizontalement (aspect des lettres de l'enseigne)."""
    tmp = Image.new("L", (img.width * 2, img.height), 0)
    d = ImageDraw.Draw(tmp)
    l, t, r, b = d.textbbox((0, 0), txt, font=f)
    w, h = r - l, b - t
    d.text((-l + 4, -t + 4), txt, font=f, fill=255)
    masque = tmp.crop((0, 0, w + 8, h + 8))
    masque = masque.resize((max(1, int((w + 8) * sx)), h + 8), Image.LANCZOS)
    couche = Image.new("RGB", masque.size, fill)
    img.paste(couche, (int(cx - masque.width / 2), int(cy - masque.height / 2)), masque)


# --- 1. Enseigne « POLICE PUBLIC CALL BOX » (2048 x 256, ratio ~ 1,28 m x 0,16 m)
W, H = 2048, 256
sign = Image.new("RGB", (W, H), (8, 8, 10))
fg = police(GRAS, 190)
fp = police(GRAS, 84)
texte_etroit(sign, W * 0.215, H * 0.53, "POLICE", fg, CREME, 0.86)
texte_etroit(sign, W * 0.500, H * 0.33, "PUBLIC", fp, CREME, 0.86)
texte_etroit(sign, W * 0.500, H * 0.72, "CALL", fp, CREME, 0.86)
texte_etroit(sign, W * 0.80, H * 0.53, "BOX", fg, CREME, 0.86)
sign.save(os.path.join(SORTIE, "enseigne_police_box.png"))

# --- 2. Plaque « POLICE TELEPHONE ... PULL TO OPEN » (600 x 760)
W, H = 600, 760
pl = Image.new("RGB", (W, H), (238, 234, 222))
d = ImageDraw.Draw(pl)
d.rectangle((10, 10, W - 11, H - 11), outline=(30, 30, 30), width=6)
d.rectangle((24, 24, W - 25, H - 25), outline=(30, 30, 30), width=2)
lignes = [
    ("POLICE TELEPHONE", GRAS, 50, 92),
    ("FREE", GRAS, 64, 175),
    ("FOR USE OF", NORMAL, 40, 240),
    ("PUBLIC", GRAS, 64, 305),
    ("ADVICE & ASSISTANCE", NORMAL, 36, 385),
    ("OBTAINABLE IMMEDIATELY", NORMAL, 33, 430),
    ("OFFICERS & CARS", NORMAL, 36, 495),
    ("RESPOND TO ALL CALLS", NORMAL, 33, 540),
    ("PULL TO OPEN", GRAS, 58, 650),
]
for txt, f, taille, y in lignes:
    texte_etroit(pl, W / 2, y, txt, police(f, taille), (22, 22, 24), 0.9)
d.line((60, 600, W - 60, 600), fill=(30, 30, 30), width=3)
pl = pl.filter(ImageFilter.GaussianBlur(0.6))
pl.save(os.path.join(SORTIE, "plaque_pull_to_open.png"))

# --- 3. Badge circulaire (croix à huit pointes blanche sur fond noir)
S = 512
bd = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(bd)
c = S / 2
d.ellipse((4, 4, S - 4, S - 4), fill=(240, 236, 226, 255))
d.ellipse((22, 22, S - 22, S - 22), fill=(14, 14, 16, 255))
d.ellipse((120, 120, S - 120, S - 120), fill=(240, 236, 226, 255))
d.ellipse((132, 132, S - 132, S - 132), fill=(14, 14, 16, 255))
# croix de Malte : 4 branches en V
r_ext, r_int, demi = 112, 14, math.radians(24)
for k in range(4):
    a = math.radians(90 * k)
    p0 = (c + r_int * math.cos(a), c + r_int * math.sin(a))
    p1 = (c + r_ext * math.cos(a - demi), c + r_ext * math.sin(a - demi))
    pm = (c + r_ext * 0.72 * math.cos(a), c + r_ext * 0.72 * math.sin(a))
    p2 = (c + r_ext * math.cos(a + demi), c + r_ext * math.sin(a + demi))
    d.polygon([p0, p1, pm, p2], fill=(240, 236, 226, 255))
# texte en couronne
ft = police(GRAS, 40)
txt = "ST JOHN AMBULANCE  •  "
n = len(txt)
for i, ch in enumerate(txt):
    ang = -math.pi / 2 + 2 * math.pi * i / n
    lettre = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
    ImageDraw.Draw(lettre).text((14, 6), ch, font=ft, fill=(240, 236, 226, 255))
    lettre = lettre.rotate(-math.degrees(ang) - 90, resample=Image.BICUBIC)
    x = c + 178 * math.cos(ang) - 30
    y = c + 178 * math.sin(ang) - 30
    bd.alpha_composite(lettre, (int(x), int(y)))
bd.save(os.path.join(SORTIE, "badge_st_john.png"))
print("Textures écrites dans", SORTIE)
