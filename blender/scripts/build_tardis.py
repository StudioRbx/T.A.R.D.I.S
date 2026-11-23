"""Construit la scène Blender du TARDIS (ère du 15e Docteur) à l'échelle 1:1.

Environnement : Blender 5.3 (module Python `bpy`), moteur Cycles.
Lancement (module bpy)   : python build_tardis.py
Lancement (Blender)      : blender -b -P blender/scripts/build_tardis.py
Options (variables d'environnement) :
    TARDIS_RENDU=0       pas de rendu (sauvegarde seule)
    TARDIS_ECHANTILLONS  échantillons Cycles (défaut 128)

Sorties (dans blender/) : TARDIS_15e_Docteur.blend, render_preview.png,
render_portes_ouvertes.png.

Repère : avant du TARDIS vers -Y, Z vers le haut, sol en Z = 0, unités en mètres.
Portes : origine de chaque battant sur l'axe de ses charnières ; une rotation en Z
ouvre la porte vers l'intérieur (gauche : angle positif, droite : angle négatif).
"""
import math
import os

import bpy  # doit précéder bmesh avec le module pip « bpy »
import bmesh
from mathutils import Matrix, Vector

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, ".."))
TEXTURES = os.path.join(RACINE, "textures")

# ---------------------------------------------------------------------------
# Cotes (mètres)
# ---------------------------------------------------------------------------
SOCLE_DEMI = 0.77        # socle 1,54 x 1,54
SOCLE_H = 0.10
CORPS_DEMI = 0.72        # extérieur des montants d'angle : 1,44 x 1,44
MONTANT = 0.17           # section des montants d'angle
OUVERTURE_DEMI = CORPS_DEMI - MONTANT   # 0,55 : demi-largeur entre montants
PLAN_FACADE = CORPS_DEMI - 0.06         # plan médian des portes (retrait 6 cm)
EP_PORTE = 0.05
JEU = 0.003              # jeu entre battants et montants
PORTE_Z0 = SOCLE_H + 0.005
PORTE_Z1 = 2.025
LINTEAU_Z1 = 2.10
ENSEIGNE_Z0, ENSEIGNE_Z1 = 2.10, 2.30
ENSEIGNE_DEMI = 0.75

ANGLES_FACES = {"Avant": 0.0, "Droite": 90.0, "Arriere": 180.0, "Gauche": -90.0}


# ---------------------------------------------------------------------------
# Outils généraux
# ---------------------------------------------------------------------------
def nettoyer_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(nom):
    c = bpy.data.collections.get(nom)
    if c is None:
        c = bpy.data.collections.new(nom)
        bpy.context.scene.collection.children.link(c)
    return c


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def ajouter_boite(bm, centre, taille, R, decalage):
    """Ajoute un pavé (repère local de façade) au bmesh, transformé par R puis
    exprimé relativement à `decalage` (origine de l'objet, coordonnées monde)."""
    cx, cy, cz = centre
    sx, sy, sz = (t / 2 for t in taille)
    coins = [Vector((cx + dx * sx, cy + dy * sy, cz + dz * sz))
             for dz in (-1, 1) for dy in (-1, 1) for dx in (-1, 1)]
    vs = [bm.verts.new(R @ c - decalage) for c in coins]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    for f in faces:
        bm.faces.new([vs[i] for i in f])


def finaliser_mesh(bm, nom):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return me


def biseau(obj, largeur=0.0025, segments=2):
    m = obj.modifiers.new("Biseau", "BEVEL")
    m.width = largeur
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(40)
    m.harden_normals = True
    m.use_clamp_overlap = True
    w = obj.modifiers.new("Normales_Ponderees", "WEIGHTED_NORMAL")
    w.keep_sharp = True


def objet_boites(nom, boites, mat, coll, origine=Vector(), R=Matrix.Identity(3),
                 parent=None, bev=0.0025):
    """Crée un objet maillé à partir d'une liste de (centre, taille) en repère local."""
    bm = bmesh.new()
    for c, t in boites:
        ajouter_boite(bm, c, t, R, origine)
    me = finaliser_mesh(bm, nom)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    if parent is not None:
        ob.parent = parent
        ob.location = origine - parent.location
    else:
        ob.location = origine
    if bev:
        biseau(ob, bev)
    return ob


def objet_plan(nom, centre_local, largeur, hauteur, mat, coll, R=Matrix.Identity(3),
               origine=Vector(), parent=None):
    """Plan texturé (UV 0-1) orienté vers l'extérieur de la façade (-Y local)."""
    cx, cy, cz = centre_local
    w, h = largeur / 2, hauteur / 2
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    pts = [(-w, -h), (w, -h), (w, h), (-w, h)]
    vs = [bm.verts.new(R @ Vector((cx + x, cy, cz + z)) - origine) for x, z in pts]
    f = bm.faces.new(vs)
    for loop, (u, v) in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uv].uv = (u, v)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    if parent is not None:
        ob.parent = parent
        ob.location = origine - parent.location
    else:
        ob.location = origine
    return ob


def objet_cylindre(nom, centre, r1, r2, hauteur, mat, coll, seg=32, parent=None,
                   bev=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=hauteur)
    me = finaliser_mesh(bm, nom)
    for p in me.polygons:
        p.use_smooth = abs(p.normal.z) < 0.5
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    c = Vector(centre)
    if parent is not None:
        ob.parent = parent
        ob.location = c - parent.location
    else:
        ob.location = c
    if bev:
        biseau(ob, bev)
    return ob


def objet_sphere(nom, centre, r, mat, coll):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=r)
    me = finaliser_mesh(bm, nom)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    ob.location = centre
    return ob


def objet_tronc_pyramide(nom, z0, z1, demi_bas, demi_haut, mat, coll, bev=0.004):
    bm = bmesh.new()
    bas = [bm.verts.new((x * demi_bas, y * demi_bas, z0))
           for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    haut = [bm.verts.new((x * demi_haut, y * demi_haut, z1))
            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(list(reversed(bas)))
    bm.faces.new(haut)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((bas[i], bas[j], haut[j], haut[i]))
    me = finaliser_mesh(bm, nom)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nom, me)
    coll.objects.link(ob)
    biseau(ob, bev)
    return ob


# ---------------------------------------------------------------------------
# Matériaux
# ---------------------------------------------------------------------------
def nouveau_mat(nom):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (900, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (550, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m, nt, bsdf


def entree(bsdf, *noms):
    for n in noms:
        if n in bsdf.inputs:
            return bsdf.inputs[n]
    raise KeyError(noms)


def mat_bois_peint(nom, couleur_lin, usure_lin, rugo=0.55):
    """Bois peint : grain en relief (bump), rugosité variable, usure sur les arêtes."""
    m, nt, bsdf = nouveau_mat(nom)
    L = nt.links
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0, 1.0, 0.08)  # grain étiré en Z
    L.new(coord.outputs["Object"], mapping.inputs["Vector"])

    vague = nt.nodes.new("ShaderNodeTexWave")
    vague.wave_type = "RINGS"
    vague.inputs["Scale"].default_value = 9.0
    vague.inputs["Distortion"].default_value = 9.0
    vague.inputs["Detail"].default_value = 6.0
    vague.inputs["Detail Scale"].default_value = 1.5
    L.new(mapping.outputs["Vector"], vague.inputs["Vector"])

    bruit = nt.nodes.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 60.0
    bruit.inputs["Detail"].default_value = 8.0
    L.new(coord.outputs["Object"], bruit.inputs["Vector"])

    gros = nt.nodes.new("ShaderNodeTexNoise")
    gros.inputs["Scale"].default_value = 3.0
    gros.inputs["Detail"].default_value = 4.0
    L.new(coord.outputs["Object"], gros.inputs["Vector"])

    # Couleur : peinture + légères variations
    var = nt.nodes.new("ShaderNodeMix")
    var.data_type = "RGBA"
    var.blend_type = "MULTIPLY"
    var.inputs["Factor"].default_value = 0.25
    var.inputs["A"].default_value = (*couleur_lin, 1)
    rampe = nt.nodes.new("ShaderNodeValToRGB")
    rampe.color_ramp.elements[0].color = (0.75, 0.75, 0.78, 1)
    rampe.color_ramp.elements[1].color = (1.15, 1.15, 1.15, 1)
    L.new(gros.outputs["Fac"], rampe.inputs["Fac"])
    L.new(rampe.outputs["Color"], var.inputs["B"])

    # Usure des arêtes (AO inversé = arêtes saillantes)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inside = True
    ao.samples = 8
    ao.inputs["Distance"].default_value = 0.006
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    L.new(ao.outputs["AO"], inv.inputs[1])
    masque = nt.nodes.new("ShaderNodeMath")
    masque.operation = "MULTIPLY"
    L.new(inv.outputs[0], masque.inputs[0])
    L.new(bruit.outputs["Fac"], masque.inputs[1])
    seuil = nt.nodes.new("ShaderNodeMapRange")
    seuil.inputs["From Min"].default_value = 0.15
    seuil.inputs["From Max"].default_value = 0.45
    L.new(masque.outputs[0], seuil.inputs["Value"])

    usure = nt.nodes.new("ShaderNodeMix")
    usure.data_type = "RGBA"
    usure.inputs["B"].default_value = (*usure_lin, 1)
    L.new(seuil.outputs["Result"], usure.inputs["Factor"])
    L.new(var.outputs["Result"], usure.inputs["A"])
    L.new(usure.outputs["Result"], entree(bsdf, "Base Color"))

    # Rugosité
    rg = nt.nodes.new("ShaderNodeMapRange")
    rg.inputs["To Min"].default_value = rugo - 0.12
    rg.inputs["To Max"].default_value = rugo + 0.15
    L.new(gros.outputs["Fac"], rg.inputs["Value"])
    L.new(rg.outputs["Result"], entree(bsdf, "Roughness"))

    # Relief : grain + biseau ombré
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.0006
    L.new(vague.outputs["Fac"], bump.inputs["Height"])
    bevn = nt.nodes.new("ShaderNodeBevel")
    bevn.samples = 6
    bevn.inputs["Radius"].default_value = 0.002
    L.new(bevn.outputs["Normal"], bump.inputs["Normal"])
    L.new(bump.outputs["Normal"], entree(bsdf, "Normal"))
    entree(bsdf, "Coat Weight", "Coat").default_value = 0.08
    return m


def mat_image(nom, fichier, emission=0.0, rugo=0.35, alpha=False):
    m, nt, bsdf = nouveau_mat(nom)
    img = bpy.data.images.load(os.path.join(TEXTURES, fichier))
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Cubic"
    nt.links.new(tex.outputs["Color"], entree(bsdf, "Base Color"))
    entree(bsdf, "Roughness").default_value = rugo
    if emission:
        nt.links.new(tex.outputs["Color"], entree(bsdf, "Emission Color", "Emission"))
        entree(bsdf, "Emission Strength").default_value = emission
    if alpha:
        nt.links.new(tex.outputs["Alpha"], entree(bsdf, "Alpha"))
    return m


def mat_verre_givre():
    """Verre martelé/givré : transmission rugueuse + relief + lueur chaude."""
    m, nt, bsdf = nouveau_mat("Verre_Givre")
    L = nt.links
    entree(bsdf, "Base Color").default_value = (1.0, 0.93, 0.8, 1)
    entree(bsdf, "Transmission Weight", "Transmission").default_value = 0.9
    entree(bsdf, "Roughness").default_value = 0.42
    entree(bsdf, "IOR").default_value = 1.5
    entree(bsdf, "Emission Color", "Emission").default_value = (1.0, 0.78, 0.48, 1)
    entree(bsdf, "Emission Strength").default_value = 1.6
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 140.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.0005
    L.new(vor.outputs["Distance"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], entree(bsdf, "Normal"))
    return m


def mat_metal(nom, couleur, rugo, metal=1.0):
    m, nt, bsdf = nouveau_mat(nom)
    L = nt.links
    entree(bsdf, "Base Color").default_value = (*couleur, 1)
    entree(bsdf, "Metallic").default_value = metal
    bruit = nt.nodes.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 90.0
    rg = nt.nodes.new("ShaderNodeMapRange")
    rg.inputs["To Min"].default_value = rugo - 0.1
    rg.inputs["To Max"].default_value = rugo + 0.15
    L.new(bruit.outputs["Fac"], rg.inputs["Value"])
    L.new(rg.outputs["Result"], entree(bsdf, "Roughness"))
    return m


def mat_emission(nom, couleur, force):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*couleur, 1)
    em.inputs["Strength"].default_value = force
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def mat_verre_lanterne():
    m, nt, bsdf = nouveau_mat("Verre_Lanterne")
    entree(bsdf, "Base Color").default_value = (1, 1, 1, 1)
    entree(bsdf, "Transmission Weight", "Transmission").default_value = 1.0
    entree(bsdf, "Roughness").default_value = 0.18
    entree(bsdf, "IOR").default_value = 1.45
    return m


def mat_sol():
    """Herbe rase procédurale (couleur + relief), suffisante pour un aperçu."""
    m, nt, bsdf = nouveau_mat("Sol_Herbe")
    L = nt.links
    coord = nt.nodes.new("ShaderNodeTexCoord")
    b1 = nt.nodes.new("ShaderNodeTexNoise")
    b1.inputs["Scale"].default_value = 0.6
    b1.inputs["Detail"].default_value = 6
    b2 = nt.nodes.new("ShaderNodeTexNoise")
    b2.inputs["Scale"].default_value = 180.0
    b2.inputs["Detail"].default_value = 4
    for b in (b1, b2):
        L.new(coord.outputs["Object"], b.inputs["Vector"])
    rampe = nt.nodes.new("ShaderNodeValToRGB")
    rampe.color_ramp.elements[0].color = (0.035, 0.06, 0.018, 1)
    rampe.color_ramp.elements[1].color = (0.11, 0.13, 0.04, 1)
    L.new(b1.outputs["Fac"], rampe.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.6
    L.new(rampe.outputs["Color"], mix.inputs["A"])
    L.new(b2.outputs["Color"], mix.inputs["B"])
    L.new(mix.outputs["Result"], entree(bsdf, "Base Color"))
    entree(bsdf, "Roughness").default_value = 0.92
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    L.new(b2.outputs["Fac"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], entree(bsdf, "Normal"))
    return m


# ---------------------------------------------------------------------------
# Battant (repère local de façade : x le long du mur, -y vers l'extérieur)
# ---------------------------------------------------------------------------
MONTANT_PORTE = 0.075
TRAVERSE_HAUT = 0.075
FENETRE_H = 0.46
TRAVERSE_FENETRE = 0.07
TRAVERSE_BAS = 0.12
TRAVERSE_INTER = 0.065
EP_PANNEAU = 0.018
PETIT_BOIS = 0.022


def battant(x0, x1, z0, z1, yc, cote_rencontre=None):
    """Retourne les pièces d'un battant : dict tag -> [(centre, taille)] et
    les centres utiles (panneau haut, fenêtre)."""
    t = EP_PORTE
    p = {"cadre": [], "panneaux": [], "petits_bois": [], "vitre": []}
    w = x1 - x0
    xm = (x0 + x1) / 2
    # montants
    p["cadre"].append(((x0 + MONTANT_PORTE / 2, yc, (z0 + z1) / 2), (MONTANT_PORTE, t, z1 - z0)))
    p["cadre"].append(((x1 - MONTANT_PORTE / 2, yc, (z0 + z1) / 2), (MONTANT_PORTE, t, z1 - z0)))
    xi0, xi1 = x0 + MONTANT_PORTE, x1 - MONTANT_PORTE
    li = xi1 - xi0
    xc = (xi0 + xi1) / 2

    def traverse(za, zb):
        p["cadre"].append(((xc, yc, (za + zb) / 2), (li, t, zb - za)))

    # traverses de haut en bas
    zf1 = z1 - TRAVERSE_HAUT
    zf0 = zf1 - FENETRE_H
    traverse(zf1, z1)
    traverse(zf0 - TRAVERSE_FENETRE, zf0)
    zp_haut = zf0 - TRAVERSE_FENETRE
    zp_bas = z0 + TRAVERSE_BAS
    traverse(z0, zp_bas)
    h_pan = (zp_haut - zp_bas - 2 * TRAVERSE_INTER) / 3
    ouvertures = []
    z = zp_haut
    for i in range(3):
        za, zb = z - h_pan, z
        ouvertures.append((za, zb))
        if i < 2:
            traverse(za - TRAVERSE_INTER, za)
        z = za - TRAVERSE_INTER

    # panneaux encastrés + moulures (deux faces)
    for za, zb in ouvertures:
        zc = (za + zb) / 2
        p["panneaux"].append(((xc, yc, zc), (li + 0.02, EP_PANNEAU, (zb - za) + 0.02)))
        m, d = 0.014, 0.012
        for s in (-1, 1):
            ym = yc + s * (EP_PANNEAU / 2 + d / 2)
            p["cadre"].append(((xc, ym, zb - m / 2), (li, d, m)))
            p["cadre"].append(((xc, ym, za + m / 2), (li, d, m)))
            p["cadre"].append(((xi0 + m / 2, ym, zc), (m, d, zb - za - 2 * m)))
            p["cadre"].append(((xi1 - m / 2, ym, zc), (m, d, zb - za - 2 * m)))

    # fenêtre : 3 colonnes x 2 rangées
    zfc = (zf0 + zf1) / 2
    p["vitre"].append(((xc, yc, zfc), (li + 0.016, 0.006, FENETRE_H + 0.016)))
    for k in (1, 2):
        xk = xi0 + li * k / 3
        p["petits_bois"].append(((xk, yc, zfc), (PETIT_BOIS, 0.03, FENETRE_H)))
    p["petits_bois"].append(((xc, yc, zfc), (li, 0.03, PETIT_BOIS)))

    # couvre-joint central sur le battant qui porte la serrure
    if cote_rencontre is not None:
        xs = x0 + 0.016 if cote_rencontre == "gauche" else x1 - 0.016
        p["cadre"].append(((xs, yc - t / 2 - 0.005, (z0 + z1) / 2), (0.032, 0.01, z1 - z0)))

    infos = {
        "panneau_haut": (xc, (ouvertures[0][0] + ouvertures[0][1]) / 2),
        "panneau_milieu": (xc, (ouvertures[1][0] + ouvertures[1][1]) / 2),
        "largeur_interieure": li,
        "x_rencontre": x0 if cote_rencontre == "gauche" else x1,
    }
    return p, infos


def pieces_facade():
    """Les deux battants d'une façade, repère local (façade avant)."""
    yc = -PLAN_FACADE
    xa, xb = -OUVERTURE_DEMI + JEU, -JEU / 2
    g, ig = battant(xa, xb, PORTE_Z0, PORTE_Z1, yc)
    d, idr = battant(JEU / 2, OUVERTURE_DEMI - JEU, PORTE_Z0, PORTE_Z1, yc, "gauche")
    return (g, ig, xa), (d, idr, OUVERTURE_DEMI - JEU)


# ---------------------------------------------------------------------------
# Construction de la scène
# ---------------------------------------------------------------------------
def construire():
    nettoyer_scene()
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.length_unit = "METERS"
    sc.unit_settings.scale_length = 1.0

    C1 = collection("01_Structure_Principale")
    C2 = collection("02_Portes")
    C3 = collection("03_Toit_Et_Lanterne")
    C4 = collection("04_Panneaux_Et_Quincaillerie")
    C5 = collection("05_Eclairage_Et_Camera")
    C6 = collection("06_Interieur")
    C7 = collection("07_Environnement")

    # Bleu TARDIS ère 13e-15e Docteur : bleu marine désaturé (sRGB ~ #182435)
    BLEU = (0.0085, 0.0170, 0.0350)
    M_BOIS = mat_bois_peint("Bois_Peint_Bleu_TARDIS", BLEU, (0.05, 0.06, 0.075))
    M_BOIS_INT = mat_bois_peint("Bois_Peint_Interieur", (0.62, 0.6, 0.55), (0.3, 0.22, 0.14), 0.6)
    M_VERRE = mat_verre_givre()
    M_ENSEIGNE = mat_image("Enseigne_Lumineuse", "enseigne_police_box.png", emission=3.0, rugo=0.12)
    M_PLAQUE = mat_image("Plaque_Pull_To_Open", "plaque_pull_to_open.png", emission=0.35, rugo=0.3)
    M_BADGE = mat_image("Badge_St_John", "badge_st_john.png", rugo=0.25, alpha=True)
    M_LAITON = mat_metal("Laiton_Vieilli", (0.42, 0.29, 0.11), 0.38)
    M_FER = mat_metal("Metal_Noir_Patine", (0.02, 0.022, 0.026), 0.5, 0.85)
    M_VERRE_L = mat_verre_lanterne()
    M_AMPOULE = mat_emission("Ampoule_Lanterne", (1.0, 0.82, 0.55), 25.0)
    M_PLAFOND = mat_emission("Plafond_Lumineux", (1.0, 0.86, 0.66), 4.0)
    M_SOL = mat_sol()

    # --- 01 Structure : socle, montants, linteaux, caisson d'enseigne
    objet_boites("Socle", [((0, 0, SOCLE_H / 2), (2 * SOCLE_DEMI, 2 * SOCLE_DEMI, SOCLE_H))],
                 M_BOIS, C1, bev=0.006)
    pc = CORPS_DEMI - MONTANT / 2
    hz = LINTEAU_Z1 - SOCLE_H
    for nom, (sx, sy) in {"AvG": (-1, -1), "AvD": (1, -1), "ArD": (1, 1), "ArG": (-1, 1)}.items():
        objet_boites(f"Montant_{nom}", [((sx * pc, sy * pc, SOCLE_H + hz / 2), (MONTANT, MONTANT, hz))],
                     M_BOIS, C1, bev=0.005)
    for face, ang in ANGLES_FACES.items():
        R = rot_z(ang)
        linteau = [((0, -PLAN_FACADE, (PORTE_Z1 + LINTEAU_Z1) / 2 + 0.0025),
                    (2 * OUVERTURE_DEMI, EP_PORTE + 0.01, LINTEAU_Z1 - PORTE_Z1 - 0.005))]
        objet_boites(f"Linteau_{face}", linteau, M_BOIS, C1, R=R)
    objet_boites("Caisson_Enseigne",
                 [((0, 0, (ENSEIGNE_Z0 + ENSEIGNE_Z1) / 2),
                   (2 * ENSEIGNE_DEMI, 2 * ENSEIGNE_DEMI, ENSEIGNE_Z1 - ENSEIGNE_Z0))],
                 M_BOIS, C1, bev=0.005)
    for face, ang in ANGLES_FACES.items():
        R = rot_z(ang)
        mould = [((0, -ENSEIGNE_DEMI - 0.008, ENSEIGNE_Z1 - 0.012), (2 * ENSEIGNE_DEMI + 0.03, 0.016, 0.024)),
                 ((0, -ENSEIGNE_DEMI - 0.008, ENSEIGNE_Z0 + 0.012), (2 * ENSEIGNE_DEMI + 0.03, 0.016, 0.024))]
        objet_boites(f"Moulures_Enseigne_{face}", mould, M_BOIS, C1, R=R, bev=0.003)

    # --- Façades fixes (droite, arrière, gauche) : deux faux battants chacune
    (g, _, _), (d, _, _) = pieces_facade()
    for face in ("Droite", "Arriere", "Gauche"):
        R = rot_z(ANGLES_FACES[face])
        bois = g["cadre"] + g["panneaux"] + g["petits_bois"] + d["cadre"] + d["panneaux"] + d["petits_bois"]
        objet_boites(f"Facade_{face}", bois, M_BOIS, C1, R=R)
        objet_boites(f"Facade_{face}_Vitres", g["vitre"] + d["vitre"], M_VERRE, C1, R=R, bev=0)

    # --- 02 Portes avant : origine sur l'axe des charnières (face intérieure)
    (g, ig, xg), (d, idr, xd) = pieces_facade()
    y_axe = -PLAN_FACADE + EP_PORTE / 2  # face intérieure des battants
    portes = {}
    for nom, pieces, x_axe in (("Porte_Gauche", g, xg), ("Porte_Droite", d, xd)):
        axe = Vector((x_axe, y_axe, PORTE_Z0))
        racine = objet_boites(nom, pieces["cadre"], M_BOIS, C2, origine=axe)
        objet_boites(f"{nom}_Panneaux", pieces["panneaux"], M_BOIS, C2, origine=axe, parent=racine)
        objet_boites(f"{nom}_Petits_Bois", pieces["petits_bois"], M_BOIS, C2, origine=axe,
                     parent=racine, bev=0.0015)
        objet_boites(f"{nom}_Vitre", pieces["vitre"], M_VERRE, C2, origine=axe, parent=racine, bev=0)
        for i, zc in enumerate((0.35, 1.05, 1.80)):  # charnières sur l'axe
            objet_cylindre(f"{nom}_Charniere_{i + 1}", (x_axe, y_axe, zc), 0.011, 0.011, 0.09,
                           M_FER, C4, seg=16, parent=racine)
        racine["axe_rotation"] = "Z"
        racine["ouverture"] = "angle positif" if nom == "Porte_Gauche" else "angle negatif"
        portes[nom] = racine

    y_face = -PLAN_FACADE - EP_PORTE / 2  # face extérieure des battants
    pg, pd = portes["Porte_Gauche"], portes["Porte_Droite"]

    # Plaque « POLICE TELEPHONE ... PULL TO OPEN » (porte gauche, panneau haut)
    xc, zc = ig["panneau_haut"]
    cadre_pl = [((xc, y_face - 0.006, zc), (0.27, 0.012, 0.33))]
    objet_boites("Plaque_Cadre", cadre_pl, M_BOIS, C4, origine=pg.location.copy(), parent=pg, bev=0.002)
    objet_plan("Plaque_Pull_To_Open", (xc, y_face - 0.0125, zc), 0.235, 0.297, M_PLAQUE, C4,
               origine=pg.location.copy(), parent=pg)
    objet_boites("Plaque_Bouton", [((xc + 0.115, y_face - 0.018, zc), (0.012, 0.012, 0.012))], M_LAITON, C4,
                 origine=pg.location.copy(), parent=pg, bev=0.004)

    # Badge St John Ambulance (porte droite, panneau haut)
    xc, zc = idr["panneau_haut"]
    objet_plan("Badge_St_John", (xc, y_face - 0.0105, zc), 0.15, 0.15, M_BADGE, C4,
               origine=pd.location.copy(), parent=pd)

    # Serrure Yale + poignée (porte droite, côté rencontre)
    xs = idr["x_rencontre"] + 0.045
    objet_boites("Serrure_Plaque", [((xs, y_face - 0.003, 1.20), (0.036, 0.006, 0.085))], M_LAITON, C4,
                 origine=pd.location.copy(), parent=pd, bev=0.0015)
    objet_boites("Serrure_Trou", [((xs, y_face - 0.0062, 1.21), (0.006, 0.002, 0.016))], M_FER, C4,
                 origine=pd.location.copy(), parent=pd, bev=0)
    objet_boites("Poignee_Porte", [((xs, y_face - 0.022, 1.10), (0.016, 0.012, 0.11)),
                                   ((xs, y_face - 0.01, 1.05), (0.012, 0.024, 0.012)),
                                   ((xs, y_face - 0.01, 1.15), (0.012, 0.024, 0.012))],
                 M_FER, C4, origine=pd.location.copy(), parent=pd, bev=0.002)

    # Enseignes lumineuses sur les quatre faces
    for face, ang in ANGLES_FACES.items():
        R = rot_z(ang)
        objet_plan(f"Enseigne_{face}", (0, -ENSEIGNE_DEMI - 0.0012, (ENSEIGNE_Z0 + ENSEIGNE_Z1) / 2),
                   1.28, 0.16, M_ENSEIGNE, C4, R=R)

    # --- 03 Toit à gradins et lanterne
    objet_boites("Corniche_1", [((0, 0, 2.33), (1.62, 1.62, 0.06))], M_BOIS, C3, bev=0.006)
    objet_boites("Corniche_2", [((0, 0, 2.39), (1.52, 1.52, 0.06))], M_BOIS, C3, bev=0.006)
    objet_boites("Corniche_3", [((0, 0, 2.445), (1.42, 1.42, 0.05))], M_BOIS, C3, bev=0.005)
    objet_tronc_pyramide("Toit", 2.47, 2.64, 0.70, 0.17, M_BOIS, C3)
    # Lanterne : socle en bois à deux gradins, cage en métal noir, verre clair
    objet_boites("Socle_Lanterne_1", [((0, 0, 2.66), (0.32, 0.32, 0.04))], M_BOIS, C3, bev=0.004)
    objet_boites("Socle_Lanterne_2", [((0, 0, 2.695), (0.26, 0.26, 0.03))], M_BOIS, C3, bev=0.004)
    objet_cylindre("Lanterne_Base", (0, 0, 2.73), 0.115, 0.105, 0.04, M_FER, C3, bev=0.002)
    objet_cylindre("Lanterne_Anneau_Bas", (0, 0, 2.757), 0.10, 0.10, 0.016, M_FER, C3, bev=0.0015)
    objet_cylindre("Lanterne_Verre", (0, 0, 2.865), 0.085, 0.085, 0.20, M_VERRE_L, C3, seg=48)
    objet_cylindre("Lanterne_Anneau_Haut", (0, 0, 2.973), 0.10, 0.10, 0.016, M_FER, C3, bev=0.0015)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        objet_cylindre(f"Lanterne_Barreau_{k + 1}", (0.091 * math.cos(a), 0.091 * math.sin(a), 2.865),
                       0.008, 0.008, 0.20, M_FER, C3, seg=12)
    objet_cylindre("Lanterne_Chapeau", (0, 0, 3.005), 0.115, 0.04, 0.05, M_FER, C3, bev=0.002)
    objet_cylindre("Lanterne_Cheminee", (0, 0, 3.045), 0.034, 0.025, 0.03, M_FER, C3)
    objet_sphere("Lanterne_Fleuron", (0, 0, 3.07), 0.018, M_FER, C3)
    objet_sphere("Lanterne_Ampoule", (0, 0, 2.86), 0.035, M_AMPOULE, C3)

    # --- 06 Intérieur : plancher, plafond lumineux, doublage intérieur des montants
    objet_boites("Interieur_Plancher", [((0, 0, SOCLE_H + 0.004), (2 * OUVERTURE_DEMI + 0.1, 2 * OUVERTURE_DEMI + 0.1, 0.008))],
                 M_BOIS_INT, C6, bev=0)
    objet_boites("Interieur_Plafond", [((0, 0, LINTEAU_Z1 - 0.006), (2 * PLAN_FACADE, 2 * PLAN_FACADE, 0.012))],
                 M_BOIS_INT, C6, bev=0)
    objet_boites("Interieur_Plafonnier", [((0, 0, LINTEAU_Z1 - 0.014), (0.6, 0.6, 0.006))],
                 M_PLAFOND, C6, bev=0)

    # --- 07 Environnement : sol
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=400)
    me = finaliser_mesh(bm, "Sol")
    me.materials.append(M_SOL)
    sol = bpy.data.objects.new("Sol", me)
    C7.objects.link(sol)

    # --- 05 Éclairage et caméra
    def lampe(nom, type_, energie, loc, rot=(0, 0, 0), couleur=(1, 1, 1), **kw):
        ld = bpy.data.lights.new(nom, type_)
        ld.energy = energie
        ld.color = couleur
        for k, v in kw.items():
            setattr(ld, k, v)
        ob = bpy.data.objects.new(nom, ld)
        ob.location = loc
        ob.rotation_euler = [math.radians(a) for a in rot]
        C5.objects.link(ob)
        return ob

    lampe("Soleil", "SUN", 3.2, (0, 0, 10), (52, 0, -35), (1.0, 0.95, 0.88), angle=math.radians(6))
    lampe("Lumiere_Interieure", "AREA", 45, (0, 0, 2.06), couleur=(1.0, 0.78, 0.5), size=0.9)
    lampe("Lumiere_Interieure_Centre", "POINT", 25, (0, 0.1, 1.3), couleur=(1.0, 0.8, 0.55),
          shadow_soft_size=0.2)
    lampe("Lumiere_Lanterne", "POINT", 6, (0, 0, 2.86), couleur=(1.0, 0.82, 0.55), shadow_soft_size=0.02)
    lampe("Contre_Jour", "AREA", 220, (3.5, 3.0, 3.6), (-55, 0, 135), (0.75, 0.85, 1.0), size=3.0)

    world = bpy.data.worlds.new("Ciel_Couvert")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background") or nt.nodes.new("ShaderNodeBackground")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    rampe = nt.nodes.new("ShaderNodeValToRGB")
    rampe.color_ramp.elements[0].position = 0.45
    rampe.color_ramp.elements[0].color = (0.32, 0.34, 0.36, 1)
    rampe.color_ramp.elements[1].position = 0.75
    rampe.color_ramp.elements[1].color = (0.62, 0.68, 0.78, 1)
    nt.links.new(sep.outputs["Z"], rampe.inputs["Fac"])
    nt.links.new(rampe.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.1
    sc.world = world

    cam_d = bpy.data.cameras.new("Camera_Apercu")
    cam_d.lens = 45
    cam = bpy.data.objects.new("Camera_Apercu", cam_d)
    C5.objects.link(cam)
    cam.location = (-2.9, -5.2, 1.45)
    cible = Vector((0.0, 0.0, 1.47))
    cam.rotation_euler = (cible - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam

    return sc, portes


def reglages_rendu(sc, echantillons):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = echantillons
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.cycles.transmission_bounces = 8
    sc.render.resolution_x = 1080
    sc.render.resolution_y = 1350
    sc.render.resolution_percentage = int(os.environ.get("TARDIS_POURCENT", "100"))
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = 0.0


def verifier_portes(portes):
    """Vérifie qu'une ouverture à 90° ne fait pas entrer les battants dans les montants."""
    rapport = []
    for nom, ob in portes.items():
        signe = 1 if nom == "Porte_Gauche" else -1
        # les charnières sont centrées sur l'axe : elles tournent sur place, on les exclut
        enfants = [ob] + [c for c in ob.children_recursive
                          if c.type == "MESH" and "Charniere" not in c.name]
        for ang in (0, 45, 90, 95, 100):
            ob.rotation_euler.z = math.radians(signe * ang)
            bpy.context.view_layer.update()
            xmin = min((c.matrix_world @ Vector(v)).x for c in enfants for v in c.bound_box)
            xmax = max((c.matrix_world @ Vector(v)).x for c in enfants for v in c.bound_box)
            # jusqu'à 90° : ne pas mordre sur les montants ; au-delà : sur les façades latérales
            lim = OUVERTURE_DEMI if ang <= 90 else PLAN_FACADE - EP_PORTE / 2
            ok = xmin >= -lim - 1e-4 and xmax <= lim + 1e-4
            rapport.append(f"{nom} {ang:>3} deg : x de {xmin:+.3f} a {xmax:+.3f} m -> {'OK' if ok else 'COLLISION'}")
        ob.rotation_euler.z = 0.0
    bpy.context.view_layer.update()
    return rapport


def main():
    sc, portes = construire()
    ech = int(os.environ.get("TARDIS_ECHANTILLONS", "128"))
    reglages_rendu(sc, ech)
    for ligne in verifier_portes(portes):
        print(ligne)

    for img in bpy.data.images:
        if img.source == "FILE":
            img.pack()
    chemin_blend = os.path.join(RACINE, "TARDIS_15e_Docteur.blend")
    bpy.ops.wm.save_as_mainfile(filepath=chemin_blend, compress=True)
    print("Sauvegardé :", chemin_blend)

    if os.environ.get("TARDIS_RENDU", "1") != "0":
        sc.render.filepath = os.path.join(RACINE, "render_preview.png")
        bpy.ops.render.render(write_still=True)
        print("Rendu :", sc.render.filepath)
        # Vue portes ouvertes (contrôle de l'intérieur), sans modifier le .blend
        portes["Porte_Gauche"].rotation_euler.z = math.radians(70)
        portes["Porte_Droite"].rotation_euler.z = math.radians(-70)
        cam = sc.camera
        cam.location = (-0.9, -4.6, 1.4)
        cible = Vector((0.0, 0.0, 1.35))
        cam.rotation_euler = (cible - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(RACINE, "render_portes_ouvertes.png")
        bpy.ops.render.render(write_still=True)
        print("Rendu :", sc.render.filepath)


if __name__ == "__main__":
    main()
