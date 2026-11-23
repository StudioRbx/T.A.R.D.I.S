"""Cabine de police londonienne (modèle Mackenzie Trench, 1929) à l'échelle 1:1 pour l'extérieur du TARDIS.

Blender 5.x (module bpy ou Blender complet). 1 unité Blender = 1 mètre. Z vers le haut, façade (portes) vers -Y,
pied de la cabine en Z = 0, centre en X = Y = 0.

Lancer :
    python outils/blender/cabine_police_box.py modeles/cabine
ou dans Blender : Scripting > ouvrir ce fichier > Run Script (les fichiers vont alors dans le dossier du .blend
ou dans le dossier courant).

Sorties : cabine_police_box.blend, .fbx, .glb, .obj et deux rendus d'aperçu (portes fermées, portes ouvertes).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- dimensions (mètres)
HAUTEUR_TOTALE = 2.84      # 9 ft 4 in (source : article « Police box », Wikipédia)
LARGEUR = 1.37             # 4 ft 6 in, largeur du corps (poteaux d'angle compris)
DEMI = LARGEUR / 2

SOCLE_DEMI, SOCLE_H = 0.76, 0.10          # socle un peu plus large que le corps
POTEAU = 0.16                              # section des poteaux d'angle
HAUT_POTEAUX = 2.30
OUVERTURE = DEMI - POTEAU                  # demi-largeur entre poteaux (0,525)
RETRAIT = 0.03                             # les portes sont en retrait des poteaux
Y_FACE = -DEMI + RETRAIT                   # face avant du battant (-0,655)
EP_BATTANT = 0.04
SAILLIE_CADRE = 0.02                       # montants et traverses en relief
PORTE_Z0, PORTE_Z1 = 0.11, 2.22
FENETRE_Z0, FENETRE_Z1 = 1.60, 2.16
MONTANT = 0.06
ENSEIGNE_DEMI, ENSEIGNE_Z0, ENSEIGNE_Z1 = 0.725, 2.30, 2.52

# ---------------------------------------------------------------- sortie
args = [a for a in sys.argv[1:] if not a.startswith("-")]
if "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
SORTIE = os.path.abspath(args[0]) if args else (os.path.dirname(bpy.data.filepath) or os.getcwd())
os.makedirs(SORTIE, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0


# ---------------------------------------------------------------- matériaux
def materiau(nom, couleur, rugosite=0.5, metal=0.0, emission=None, force=0.0):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*couleur, 1)
    p.inputs["Roughness"].default_value = rugosite
    p.inputs["Metallic"].default_value = metal
    if emission:
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = force
    m.diffuse_color = (*couleur, 1)
    return m


MATS = {
    "peinture": materiau("Peinture_Bleu_Police", (0.012, 0.035, 0.11), 0.45),
    "enseigne": materiau("Enseigne_Noire", (0.01, 0.01, 0.012), 0.35),
    "lettres": materiau("Lettres_Blanches", (0.9, 0.9, 0.88), 0.4, emission=(1, 1, 0.95), force=0.6),
    "vitre": materiau("Vitre_Depolie", (0.85, 0.85, 0.8), 0.25, emission=(1.0, 0.92, 0.75), force=1.2),
    "plaque": materiau("Plaque_Creme", (0.8, 0.76, 0.62), 0.6),
    "laiton": materiau("Laiton", (0.75, 0.55, 0.25), 0.3, metal=1.0),
    "lampe": materiau("Lampe", (0.95, 0.95, 1.0), 0.1, emission=(0.9, 0.95, 1.0), force=4.0),
}
ORDRE = list(MATS)


# ---------------------------------------------------------------- construction de maillages
class Maillage:
    """Accumule des pavés, troncs de pyramide et cylindres dans un seul maillage (un indice de matériau par face)."""

    FACES_PAVE = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]

    def __init__(self):
        self.v, self.f, self.m = [], [], []

    def _ajout(self, sommets, faces, mat, M):
        base = len(self.v)
        self.v += [tuple(M @ Vector(s)) if M else tuple(s) for s in sommets]
        for face in faces:
            self.f.append(tuple(base + i for i in face))
            self.m.append(ORDRE.index(mat))

    def pave(self, x0, x1, y0, y1, z0, z1, mat="peinture", M=None):
        xs, ys, zs = (min(x0, x1), max(x0, x1)), (min(y0, y1), max(y0, y1)), (min(z0, z1), max(z0, z1))
        s = [(xs[i & 1], ys[(i >> 1) & 1], zs[(i >> 2) & 1]) for i in range(8)]
        self._ajout(s, self.FACES_PAVE, mat, M)

    def tronc(self, z0, z1, d0, d1, mat="peinture", M=None):
        s = [((-d if i & 1 == 0 else d), (-d if (i >> 1) & 1 == 0 else d), (z0 if i < 4 else z1))
             for i in range(8) for d in [d0 if i < 4 else d1]]
        self._ajout(s, self.FACES_PAVE, mat, M)

    def cylindre(self, cx, cy, z0, z1, r0, r1=None, seg=24, mat="peinture", M=None):
        r1 = r0 if r1 is None else r1
        bas = [(cx + r0 * math.cos(2 * math.pi * i / seg), cy + r0 * math.sin(2 * math.pi * i / seg), z0) for i in range(seg)]
        haut = [(cx + r1 * math.cos(2 * math.pi * i / seg), cy + r1 * math.sin(2 * math.pi * i / seg), z1) for i in range(seg)]
        faces = [(i, (i + 1) % seg, seg + (i + 1) % seg, seg + i) for i in range(seg)]
        faces.append(tuple(range(seg, 2 * seg)))
        faces.append(tuple(reversed(range(seg))))
        self._ajout(bas + haut, faces, mat, M)

    def objet(self, nom, collection, origine=(0, 0, 0)):
        o = Vector(origine)
        me = bpy.data.meshes.new(nom)
        me.from_pydata([tuple(Vector(v) - o) for v in self.v], [], self.f)
        me.update()
        for m in ORDRE:
            me.materials.append(MATS[m])
        me.polygons.foreach_set("material_index", self.m)
        me.validate()
        ob = bpy.data.objects.new(nom, me)
        ob.location = o
        collection.objects.link(ob)
        return ob


def rotation_face(k):
    """Face 0 = avant (-Y), 1 = droite (+X), 2 = arrière (+Y), 3 = gauche (-X)."""
    return Matrix.Rotation(k * math.pi / 2, 4, "Z")


# ---------------------------------------------------------------- un battant de porte (repère de la façade avant)
def battant(mm, xa, xb, M=None, telephone=False, serrure=False):
    """Battant entre xa et xb (xa < xb), face avant vers -Y : 3 panneaux en creux, une fenêtre de 2 × 3 carreaux."""
    yf, yb, yr = Y_FACE, Y_FACE + EP_BATTANT, Y_FACE - SAILLIE_CADRE
    z0, z1 = PORTE_Z0, PORTE_Z1
    # âme du battant : sous la fenêtre, au-dessus, et de chaque côté de la vitre
    mm.pave(xa, xb, yf, yb, z0, FENETRE_Z0, M=M)
    mm.pave(xa, xb, yf, yb, FENETRE_Z1, z1, M=M)
    mm.pave(xa, xa + MONTANT, yf, yb, FENETRE_Z0, FENETRE_Z1, M=M)
    mm.pave(xb - MONTANT, xb, yf, yb, FENETRE_Z0, FENETRE_Z1, M=M)
    # cadre en relief : montants et traverses
    mm.pave(xa, xa + MONTANT, yr, yf, z0, z1, M=M)
    mm.pave(xb - MONTANT, xb, yr, yf, z0, z1, M=M)
    xi0, xi1 = xa + MONTANT, xb - MONTANT
    bas = 0.10
    mm.pave(xi0, xi1, yr, yf, z0, z0 + bas, M=M)                       # traverse basse
    mm.pave(xi0, xi1, yr, yf, FENETRE_Z0 - MONTANT, FENETRE_Z0, M=M)   # sous la fenêtre
    mm.pave(xi0, xi1, yr, yf, FENETRE_Z1, z1, M=M)                     # traverse haute
    zp0, zp1 = z0 + bas, FENETRE_Z0 - MONTANT
    h = (zp1 - zp0 - 2 * MONTANT) / 3
    panneaux = []
    z = zp0
    for i in range(3):
        panneaux.append((z, z + h))
        z += h
        if i < 2:
            mm.pave(xi0, xi1, yr, yf, z, z + MONTANT, M=M)
            z += MONTANT
    # fenêtre : vitre et croisillons (2 colonnes × 3 rangées)
    mm.pave(xi0, xi1, yf + 0.007, yf + 0.013, FENETRE_Z0, FENETRE_Z1, mat="vitre", M=M)
    c = 0.0125
    xm = (xi0 + xi1) / 2
    mm.pave(xm - c, xm + c, yf - 0.005, yf + 0.025, FENETRE_Z0, FENETRE_Z1, M=M)
    hv = (FENETRE_Z1 - FENETRE_Z0) / 3
    for j in (1, 2):
        zz = FENETRE_Z0 + j * hv
        mm.pave(xi0, xi1, yf - 0.005, yf + 0.025, zz - c, zz + c, M=M)
    if telephone:  # petit volet du téléphone dans le panneau du milieu, avec une plaque crème sans texte
        pz0, pz1 = panneaux[1]
        f = 0.018
        mm.pave(xi0 + 0.03, xi1 - 0.03, yf - 0.012, yf, pz0 + 0.03, pz1 - 0.03, M=M)
        mm.pave(xi0 + 0.03 + f, xi1 - 0.03 - f, yf - 0.016, yf - 0.012, pz0 + 0.03 + f, pz1 - 0.03 - f, mat="plaque", M=M)
        mm.cylindre(xi1 - 0.06, yf - 0.016, pz0 + 0.18, pz0 + 0.20, 0.008, mat="laiton",
                    M=(M or Matrix()) @ Matrix.Translation((0, 0, 0)))
    if serrure:  # serrure en laiton près du montant central
        mm.pave(xa + 0.012, xa + 0.045, yr - 0.008, yr, 1.10, 1.17, mat="laiton", M=M)


# ---------------------------------------------------------------- construction
col = bpy.data.collections.new("Cabine")
scene.collection.children.link(col)
corps = Maillage()

corps.pave(-SOCLE_DEMI, SOCLE_DEMI, -SOCLE_DEMI, SOCLE_DEMI, 0, SOCLE_H)                     # socle
for sx in (-1, 1):                                                                           # poteaux d'angle
    for sy in (-1, 1):
        corps.pave(sx * OUVERTURE, sx * DEMI, sy * OUVERTURE, sy * DEMI, SOCLE_H, HAUT_POTEAUX)
corps.pave(-OUVERTURE, OUVERTURE, -OUVERTURE, OUVERTURE, SOCLE_H, SOCLE_H + 0.01)            # plancher
corps.pave(-OUVERTURE, OUVERTURE, -OUVERTURE, OUVERTURE, HAUT_POTEAUX - 0.01, HAUT_POTEAUX)  # plafond
for k in range(4):
    M = rotation_face(k)
    corps.pave(-OUVERTURE, OUVERTURE, -DEMI, Y_FACE + EP_BATTANT, PORTE_Z1, HAUT_POTEAUX, M=M)  # linteau
    if k:  # les trois autres faces : battants fixes
        battant(corps, -OUVERTURE, 0, M=M)
        battant(corps, 0, OUVERTURE, M=M)
    # panneau noir de l'enseigne
    corps.pave(-0.6, 0.6, -ENSEIGNE_DEMI - 0.006, -ENSEIGNE_DEMI, ENSEIGNE_Z0 + 0.03, ENSEIGNE_Z1 - 0.03,
               mat="enseigne", M=M)
# bandeau des enseignes et toiture à gradins
corps.pave(-ENSEIGNE_DEMI, ENSEIGNE_DEMI, -ENSEIGNE_DEMI, ENSEIGNE_DEMI, ENSEIGNE_Z0, ENSEIGNE_Z1)
corps.tronc(2.52, 2.60, 0.70, 0.70)
corps.tronc(2.60, 2.66, 0.62, 0.62)
corps.tronc(2.66, 2.74, 0.56, 0.12)
corps.objet("Corps", col)

lampe = Maillage()
lampe.cylindre(0, 0, 2.74, 2.76, 0.09)
lampe.cylindre(0, 0, 2.76, 2.81, 0.065, mat="lampe")
for i in range(4):  # quatre petits barreaux autour du globe
    a = math.pi / 4 + i * math.pi / 2
    lampe.cylindre(0.072 * math.cos(a), 0.072 * math.sin(a), 2.76, 2.81, 0.008, seg=8)
lampe.cylindre(0, 0, 2.81, 2.84, 0.085, 0.012)
lampe.objet("Lampe", col, origine=(0, 0, 2.74))

# portes avant : un objet par battant, origine sur la charnière (rotation Z = ouverture)
porte_g = Maillage()
battant(porte_g, -OUVERTURE, 0)
og = porte_g.objet("Porte_Gauche", col, origine=(-OUVERTURE, Y_FACE, PORTE_Z0))
porte_d = Maillage()
battant(porte_d, 0, OUVERTURE, telephone=True, serrure=True)
od = porte_d.objet("Porte_Droite", col, origine=(OUVERTURE, Y_FACE, PORTE_Z0))


# ---------------------------------------------------------------- texte des enseignes (inscription historique)
def texte(corps_txt, taille, x, z, k):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = corps_txt
    cu.size = taille
    cu.extrude = 0.002
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.space_line = 0.9
    cu.resolution_u = 4
    ob = bpy.data.objects.new("txt", cu)
    col.objects.link(ob)
    ob.matrix_world = rotation_face(k) @ Matrix.Translation((x, -ENSEIGNE_DEMI - 0.008, z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    ob.data.materials.append(MATS["lettres"])
    return ob


zc = (ENSEIGNE_Z0 + ENSEIGNE_Z1) / 2
textes = []
for k in range(4):
    textes += [texte("POLICE", 0.095, -0.36, zc, k), texte("PUBLIC\nCALL", 0.042, 0.0, zc, k), texte("BOX", 0.095, 0.38, zc, k)]
bpy.ops.object.select_all(action="DESELECT")
for t in textes:
    t.select_set(True)
bpy.context.view_layer.objects.active = textes[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
enseigne = bpy.context.view_layer.objects.active
enseigne.name = "Enseigne_Texte"
enseigne.data.name = "Enseigne_Texte"

# ombrage plat propre + normales
for ob in col.objects:
    for p in ob.data.polygons:
        p.use_smooth = False

# ---------------------------------------------------------------- contrôle des dimensions
def boite_globale(objets):
    pts = [ob.matrix_world @ Vector(c) for ob in objets for c in ob.bound_box]
    return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]

bpy.context.view_layer.update()
mn, mx = boite_globale(list(col.objects))
tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in col.objects)
print(f"Taille : {mx[0]-mn[0]:.3f} x {mx[1]-mn[1]:.3f} x {mx[2]-mn[2]:.3f} m ; triangles : {tris}")
for ob in col.objects:
    print(f"  {ob.name:16s} {sum(len(p.vertices)-2 for p in ob.data.polygons):6d} triangles, origine {tuple(round(c,3) for c in ob.location)}")

# ---------------------------------------------------------------- exports (la cabine seule)
nom = "cabine_police_box"
bpy.ops.object.select_all(action="DESELECT")
for ob in col.objects:
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(SORTIE, nom + ".fbx"), use_selection=True, apply_unit_scale=True,
                         apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE")
bpy.ops.export_scene.gltf(filepath=os.path.join(SORTIE, nom + ".glb"), use_selection=True, export_format="GLB")
bpy.ops.wm.obj_export(filepath=os.path.join(SORTIE, nom + ".obj"), export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y")

# ---------------------------------------------------------------- scène d'aperçu (collection à part, non exportée)
rendu = bpy.data.collections.new("Apercu")
scene.collection.children.link(rendu)
sol = Maillage()
sol.pave(-6, 6, -6, 6, -0.02, 0, mat="plaque")
sol_ob = sol.objet("Sol", rendu)
sol_ob.data.materials.clear()
sol_ob.data.materials.append(materiau("Pave", (0.25, 0.25, 0.25), 0.9))

soleil = bpy.data.objects.new("Soleil", bpy.data.lights.new("Soleil", "SUN"))
soleil.data.energy = 3.0
soleil.rotation_euler = (math.radians(50), 0, math.radians(-35))
rendu.objects.link(soleil)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.data.lens = 40
rendu.objects.link(cam)
scene.camera = cam
monde = bpy.data.worlds.new("Ciel")
monde.use_nodes = True
monde.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.45, 0.6, 1)
monde.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = monde

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 1200
scene.view_settings.view_transform = "AgX"


def viser(position, cible):
    cam.location = position
    cam.rotation_euler = (Vector(cible) - Vector(position)).to_track_quat("-Z", "Y").to_euler()


viser((3.0, -4.6, 1.9), (0, 0, 1.4))
scene.render.filepath = os.path.join(SORTIE, nom + "_apercu.png")
bpy.ops.render.render(write_still=True)

og.rotation_euler.z = math.radians(-75)
od.rotation_euler.z = math.radians(75)
viser((0.9, -4.2, 1.6), (0, 0, 1.25))
scene.render.filepath = os.path.join(SORTIE, nom + "_portes_ouvertes.png")
bpy.ops.render.render(write_still=True)
og.rotation_euler.z = od.rotation_euler.z = 0

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SORTIE, nom + ".blend"), compress=True)
print("Fichiers écrits dans", SORTIE)
