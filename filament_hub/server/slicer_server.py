"""
Сервер нарезки для Filament Hub.
Принимает STL / 3MF с телефона, режет через PrusaSlicer CLI и возвращает G-code.

Запуск (ПК или Raspberry Pi в той же Wi-Fi сети):
    pip install flask
    export PRUSA_SLICER=/usr/bin/prusa-slicer          # путь к PrusaSlicer
    export SLICER_CONFIG=/home/me/my_printer.ini       # конфиг ТВОЕГО принтера
    python slicer_server.py

Конфиг: в PrusaSlicer выбери свой принтер/пластик/профиль печати →
File → Export → Export Config… → сохрани .ini.
Без правильного конфига G-code не подойдёт твоему принтеру.
"""
import os
import subprocess
import tempfile

from flask import Flask, Response, jsonify, request

app = Flask(__name__)
SLICER = os.environ.get("PRUSA_SLICER", "prusa-slicer")
CONFIG = os.environ.get("SLICER_CONFIG", "")


@app.get("/health")
def health():
    return jsonify(ok=True, config=bool(CONFIG))


@app.post("/slice")
def slice_model():
    f = request.files.get("file")
    if not f:
        return Response("Нет файла", status=400)
    layer = request.form.get("layer", "0.2")
    infill = request.form.get("infill", "15")
    supports = request.form.get("supports", "0") == "1"

    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, os.path.basename(f.filename or "model.stl"))
        out = os.path.join(tmp, "out.gcode")
        f.save(src)
        cmd = [SLICER, "--export-gcode", "--output", out]
        if CONFIG:
            cmd += ["--load", CONFIG]
        cmd += ["--layer-height", layer, "--fill-density", f"{infill}%"]
        if supports:
            cmd += ["--support-material"]
        cmd += [src]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        except FileNotFoundError:
            return Response(f"PrusaSlicer не найден: {SLICER}", status=500)
        except subprocess.TimeoutExpired:
            return Response("Нарезка заняла слишком долго", status=500)
        if p.returncode != 0 or not os.path.exists(out):
            return Response((p.stderr or p.stdout or "Ошибка нарезки")[-1500:], status=500)
        with open(out, "rb") as g:
            data = g.read()
    return Response(data, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8765)
