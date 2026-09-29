#!/usr/bin/env python3
"""
image_to_3dscene.py — une photo → une scène 3D GLB (objets séparés et nommés),
importable dans Blender. Idée de Mira-Scene (VAST-AI-Research), refaite avec les
nodes natifs de ComfyUI, sans service externe :

  1. objets : liste donnée (--objects) ou demandée à un modèle de vision Ollama
  2. SAM3_Detect : un masque par instance de chaque objet
  3. MoGe : nuage de points métrique de toute la photo (+ maillage du décor)
  4. Pixal3D : un maillage GLB texturé par objet (template 3d_pixal3d_trellis2_image_to_model)
  5. placement : chaque objet est mis à l'échelle et posé sur les points 3D de son masque
  6. assemblage : scene.glb (décor + objets nommés), preview.png (contrôle vu de la caméra)

Usage : image_to_3dscene.py <image> [-o scene.glb] [--objects "armchair,lamp"]
        [--vision-model minicpm-v:latest] [--max-objects 6] [--no-background]
        [--faces 150000] [--workdir DIR]
Requiert ComfyUI (http://127.0.0.1:8188) équipé : sam3.1_multiplex_fp16, moge_2_vitl_normal_fp16,
pixal3d_bf16, dino_v3_L_naf_fp32, trellis_2_shape/texture_vae_bf16, birefnet.
Lancer avec ~/comfyui_env/bin/python (trimesh, numpy, PIL).
"""

import argparse
import base64
import io
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

import numpy as np
import trimesh
from PIL import Image

COMFY = "http://127.0.0.1:8188"
OLLAMA = "http://127.0.0.1:11434"
HERE = pathlib.Path(__file__).resolve().parent
PIXAL_WORKFLOW = HERE / "workflow" / "pixal3d_image_to_model_api.json"
# éléments de décor que le modèle de vision cite malgré la consigne (restent dans le décor MoGe)
DECOR = {"wall", "walls", "floor", "ceiling", "sky", "ground", "background", "room", "window", "radiator"}


# ---------------------------------------------------------------- ComfyUI
def _request(url, data=None, headers=None, timeout=60):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def upload(path):
    boundary = "----a3d" + str(time.time_ns())
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{pathlib.Path(path).name}\"\r\n"
            f"Content-Type: application/octet-stream\r\n\r\n").encode() + pathlib.Path(path).read_bytes() + \
           f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{boundary}--\r\n".encode()
    out = json.loads(_request(f"{COMFY}/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}))
    return out["name"]


def run(workflow, label):
    res = json.loads(_request(f"{COMFY}/prompt", json.dumps({"prompt": workflow}).encode(),
                              {"Content-Type": "application/json"}))
    if res.get("node_errors"):
        sys.exit(f"Erreur ComfyUI ({label}) : {json.dumps(res['node_errors'])[:500]}")
    pid, start = res["prompt_id"], time.time()
    while True:
        hist = json.loads(_request(f"{COMFY}/history/{pid}"))
        if pid in hist:
            entry = hist[pid]
            if entry["status"].get("status_str") != "success":
                errors = [m[1] for m in entry["status"].get("messages", []) if m[0] == "execution_error"]
                sys.exit(f"Erreur ComfyUI ({label}) : {errors[-1].get('exception_message', '?')[:300] if errors else '?'}")
            print(f"  {label} : {time.time() - start:.0f} s", file=sys.stderr)
            return entry["outputs"]
        time.sleep(3)


def fetch(item):
    query = urllib.parse.urlencode({"filename": item["filename"], "subfolder": item.get("subfolder", ""),
                                    "type": item.get("type", "output")})
    return _request(f"{COMFY}/view?{query}", timeout=300)


def output_files(outputs, node, key):
    return [f for f in outputs.get(node, {}).get(key, []) if isinstance(f, dict) and "filename" in f]


# ---------------------------------------------------------------- étapes
def list_objects(image_path, model, max_objects):
    """Objets principaux de la photo, en noms anglais courts (invites SAM3)."""
    prompt = (f"List the main distinct physical objects visible in this photo that a 3D artist would model "
              f"separately (furniture, props, plants, vehicles...). Ignore walls, floor, ceiling, sky, ground. "
              f"Answer only JSON: {{\"objects\": [\"short english noun\", ...]}} with at most {max_objects} items.")
    # keep_alive 0 : Ollama libère sa VRAM tout de suite, ComfyUI en a besoin ensuite
    body = {"model": model, "stream": False, "format": "json", "keep_alive": 0,
            "messages": [{"role": "user", "content": prompt,
                          "images": [base64.b64encode(pathlib.Path(image_path).read_bytes()).decode()]}]}
    res = json.loads(_request(f"{OLLAMA}/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"}, 600))
    names = json.loads(res["message"]["content"]).get("objects", [])
    clean = []
    for name in names:
        if isinstance(name, dict):  # certains modèles répondent {"type": ..., "description": ...}
            name = name.get("type") or name.get("name") or name.get("object") or ""
        name = re.sub(r"[^a-z0-9 -]", "", str(name).lower()).strip()
        if name and name not in clean and not (set(name.split()) & DECOR):
            clean.append(name)
    return clean[:max_objects]


def sam3_masks(image_name, text, prefix):
    wf = {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sam3.1_multiplex_fp16.safetensors"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": text, "clip": ["2", 1]}},
        "4": {"class_type": "SAM3_Detect", "inputs": {"model": ["2", 0], "image": ["1", 0], "conditioning": ["3", 0],
                                                      "threshold": 0.5, "refine_iterations": 2, "individual_masks": True}},
        "5": {"class_type": "MaskToImage", "inputs": {"mask": ["4", 0]}},
        "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0], "filename_prefix": prefix}},
    }
    outputs = run(wf, f"SAM3 « {text} »")
    masks = []
    for item in output_files(outputs, "6", "images"):
        m = np.array(Image.open(io.BytesIO(fetch(item))).convert("L")) > 127
        if m.sum() > 400:  # ignorer les détections minuscules
            masks.append(m)
    return masks


def moge_mesh(image_name, prefix):
    wf = {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {"class_type": "LoadMoGeModel", "inputs": {"model_name": "moge_2_vitl_normal_fp16.safetensors"}},
        "3": {"class_type": "MoGeInference", "inputs": {"moge_model": ["2", 0], "image": ["1", 0], "resolution_level": 9,
                                                        "fov_x_degrees": 0, "batch_size": 4, "force_projection": True,
                                                        "apply_mask": True}},
        "4": {"class_type": "MoGePointMapToMesh", "inputs": {"moge_geometry": ["3", 0], "batch_index": 0, "decimation": 2,
                                                             "discontinuity_threshold": 0.04, "texture": True}},
        "5": {"class_type": "SaveGLB", "inputs": {"mesh": ["4", 0], "filename_prefix": prefix}},
        "6": {"class_type": "MoGeGeometryToFOV", "inputs": {"moge_geometry": ["3", 0], "axis": "horizontal", "unit": "degrees"}},
        "7": {"class_type": "PreviewAny", "inputs": {"source": ["6", 0]}},
    }
    outputs = run(wf, "MoGe (géométrie de la scène)")
    glb = next(iter(output_files(outputs, "5", "3d") or output_files(outputs, "5", "result") or []), None)
    if not glb:
        sys.exit(f"MoGe : pas de GLB dans la sortie ({list(outputs.get('5', {}))})")
    fov = None
    for value in outputs.get("7", {}).get("text", []):
        try:
            fov = float(value)
        except (TypeError, ValueError):
            pass
    return fetch(glb), fov


def pixal_object(cutout_name, prefix, faces):
    wf = json.loads(PIXAL_WORKFLOW.read_text())
    wf["122"]["inputs"]["image"] = cutout_name
    wf["322"]["inputs"]["filename_prefix"] = prefix
    wf["186"]["inputs"]["target_face_count"] = faces
    outputs = run(wf, f"Pixal3D {prefix.rsplit('/', 1)[-1]}")
    glb = next(iter(output_files(outputs, "322", "3d") or output_files(outputs, "322", "result")), None)
    if not glb:
        sys.exit(f"Pixal3D : pas de GLB ({list(outputs.get('322', {}))})")
    return fetch(glb)


# ---------------------------------------------------------------- géométrie
def as_mesh(glb_bytes):
    scene = trimesh.load(io.BytesIO(glb_bytes), file_type="glb", force="scene")
    return trimesh.util.concatenate([g for g in scene.dump() if isinstance(g, trimesh.Trimesh)])


def pixel_of_vertices(mesh, width, height):
    """Pixel (col, ligne) de chaque sommet du maillage MoGe, via ses UV (origine glTF en haut à gauche)."""
    uv = np.asarray(mesh.visual.uv)
    cols = np.clip((uv[:, 0] * width).astype(int), 0, width - 1)
    rows = np.clip((uv[:, 1] * height).astype(int), 0, height - 1)
    # certains exports mettent l'origine en bas : on garde l'orientation où le haut de l'image est le plus haut
    top = mesh.vertices[rows < height * 0.2, 1].mean() if (rows < height * 0.2).any() else 0
    bottom = mesh.vertices[rows > height * 0.8, 1].mean() if (rows > height * 0.8).any() else 0
    if top < bottom:
        rows = height - 1 - rows
    return cols, rows


def place(obj, points, mask, fov_deg, width, height):
    """Pose l'objet dans le repère caméra de MoGe (origine = caméra, regard vers -z,
    y vers le haut) pour que sa silhouette projetée recouvre le cadre du masque.
    Pixal3D rend l'objet dans l'orientation de la photo : pas de rotation.
    La face avant est posée sur les points visibles les plus proches ; échelle et
    position sont ajustées en projetant l'objet (sa partie la plus large peut être
    plus loin que sa face avant, donc plus petite à l'image)."""
    f = (width / 2) / np.tan(np.radians(fov_deg or 60) / 2)
    d_front = float(np.percentile(-points[:, 2], 5))       # points visibles les plus proches
    ys, xs = np.nonzero(mask)
    target = np.array([xs.min(), xs.max(), ys.min(), ys.max()], float)
    omin, omax = obj.bounds
    ext = np.maximum(omax - omin, 1e-6)
    base = obj.copy()
    base.apply_translation(-(omin + omax) / 2)

    def build(scale, u, v):
        o = base.copy()
        o.apply_scale(scale)
        d_center = d_front + ext[2] * scale / 2
        o.apply_translation([(u - width / 2) / f * d_center, -(v - height / 2) / f * d_center, -d_center])
        return o

    def bbox(o):
        z = -o.vertices[:, 2]
        px = o.vertices[:, 0] / z * f + width / 2
        py = -o.vertices[:, 1] / z * f + height / 2
        return np.array([px.min(), px.max(), py.min(), py.max()])

    u, v = (target[0] + target[1]) / 2, (target[2] + target[3]) / 2
    scale = (target[1] - target[0]) * d_front / (f * ext[0])
    for _ in range(6):
        got = bbox(build(scale, u, v))
        scale *= np.mean([(target[1] - target[0]) / max(got[1] - got[0], 1),
                          (target[3] - target[2]) / max(got[3] - got[2], 1)])
        got = bbox(build(scale, u, v))
        u += (target[0] + target[1]) / 2 - (got[0] + got[1]) / 2
        v += (target[2] + target[3]) / 2 - (got[2] + got[3]) / 2
    return build(scale, u, v)


def preview(meshes, fov_deg, width, height, out_png):
    """Rendu de contrôle : sommets colorés projetés depuis la caméra (origine), z-buffer."""
    w, h = 960, int(960 * height / width)
    img = np.full((h, w, 3), 30, np.uint8)
    zbuf = np.full((h, w), np.inf)
    f = (w / 2) / np.tan(np.radians(fov_deg or 60) / 2)
    for mesh in meshes:
        pts = mesh.vertices
        try:
            colors = mesh.visual.to_color().vertex_colors[:, :3]
        except Exception:
            colors = np.full((len(pts), 3), 200, np.uint8)
        z = -pts[:, 2] if np.median(pts[:, 2]) < 0 else pts[:, 2]
        ok = z > 1e-3
        x = (pts[ok, 0] / z[ok] * f + w / 2).astype(int)
        y = (-pts[ok, 1] / z[ok] * f + h / 2).astype(int)
        zz, cc = z[ok], colors[ok]
        inside = (x >= 0) & (x < w) & (y >= 0) & (y < h)
        for xi, yi, zi, ci in zip(x[inside], y[inside], zz[inside], cc[inside]):
            if zi < zbuf[yi, xi]:
                zbuf[yi, xi] = zi
                img[yi, xi] = ci
    Image.fromarray(img).save(out_png)


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("-o", "--output")
    ap.add_argument("--objects", help="liste « a,b,c » (sinon modèle de vision Ollama)")
    ap.add_argument("--vision-model", default="minicpm-v:latest")
    ap.add_argument("--max-objects", type=int, default=6)
    ap.add_argument("--no-background", action="store_true")
    ap.add_argument("--faces", type=int, default=150000)
    ap.add_argument("--workdir")
    args = ap.parse_args()

    src = pathlib.Path(args.image).resolve()
    work = pathlib.Path(args.workdir or pathlib.Path.home() / ".zen/workspace/scenes3d" / f"{src.stem}_{int(time.time())}")
    work.mkdir(parents=True, exist_ok=True)
    out_glb = pathlib.Path(args.output or work / "scene.glb")
    image = Image.open(src).convert("RGB")
    width, height = image.size
    tag = f"scene3d/{work.name}"

    objects = [o.strip() for o in args.objects.split(",") if o.strip()] if args.objects else \
        list_objects(src, args.vision_model, args.max_objects)
    print(f"Objets : {', '.join(objects) or 'aucun'}", file=sys.stderr)
    image_name = upload(src)

    scene_glb, fov = moge_mesh(image_name, f"{tag}/background")
    (work / "background.glb").write_bytes(scene_glb)
    background = as_mesh(scene_glb)
    cols, rows = pixel_of_vertices(background, width, height)
    if np.median(background.vertices[:, 2]) > 0:
        sys.exit("MoGe : repère inattendu (caméra regardant vers +z)")

    scene = trimesh.Scene()
    placed, manifest, taken = [], [], np.zeros((height, width), bool)
    for name in objects:
        for k, mask in enumerate(sam3_masks(image_name, name, f"{tag}/mask_{name.replace(' ', '_')}")):
            label = f"{name.replace(' ', '_')}_{k + 1}"
            # déjà couvert par un objet placé (« pot » dans « plante en pot ») : on ne le double pas
            if (mask & taken).sum() > 0.6 * mask.sum():
                print(f"  {label} : contenu dans un objet déjà placé, ignoré", file=sys.stderr)
                continue
            points = background.vertices[mask[rows, cols]]
            if len(points) < 50:
                print(f"  {label} : trop peu de points 3D, ignoré", file=sys.stderr)
                continue
            # découpe de l'objet sur fond noir, recadrée par le template Pixal3D
            ys, xs = np.nonzero(mask)
            pad = int(0.1 * max(xs.ptp(), ys.ptp())) + 8
            box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, width), min(ys.max() + pad, height))
            cut = np.array(image) * mask[..., None]
            cut_path = work / f"{label}.png"
            Image.fromarray(cut.astype(np.uint8)).crop(box).save(cut_path)
            obj_path = work / f"{label}.glb"
            if obj_path.exists():  # reprise : objet déjà modélisé dans ce répertoire
                obj_glb = obj_path.read_bytes()
            else:
                obj_glb = pixal_object(upload(cut_path), f"{tag}/{label}", args.faces)
                obj_path.write_bytes(obj_glb)
            obj = place(as_mesh(obj_glb), points, mask, fov, width, height)
            scene.add_geometry(obj, node_name=label, geom_name=label)
            placed.append(obj)
            taken |= mask
            manifest.append({"objet": label, "pixels": int(mask.sum()), "points_3d": int(len(points)),
                             "taille_m": np.round(obj.bounds[1] - obj.bounds[0], 3).tolist()})

    if not args.no_background:
        # décor sans la surface des objets (sinon doublon « fantôme » derrière chaque objet)
        face_px = taken[rows[background.faces], cols[background.faces]].any(axis=1)
        decor = background.copy()
        decor.update_faces(~face_px)
        decor.remove_unreferenced_vertices()
        scene.add_geometry(decor, node_name="background", geom_name="background")
        background = decor
    scene.export(out_glb)
    preview(([background] if not args.no_background else []) + placed, fov, width, height, work / "preview.png")
    (work / "manifest.json").write_text(json.dumps({"image": str(src), "fov_deg": fov, "objets": manifest},
                                                   ensure_ascii=False, indent=1))
    print(f"Scène : {out_glb} ({len(placed)} objets) — contrôle : {work / 'preview.png'}", file=sys.stderr)
    print(out_glb)


if __name__ == "__main__":
    main()
