#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Патчер ядра OpenCode: полное отключение блокирующих всплывающих окон лимитов (go-upsell).
Сделано Антоном Ковалкиным все права защищены.
"""
import os
import sys

def patch(bin_path):
    if not os.path.exists(bin_path):
        return False
    with open(bin_path, "rb") as f:
        content = bytearray(f.read())

    patched = False
    # Target 1: if(Tn.dontShow||an.dontShow)return;
    t1 = b"if(Tn.dontShow||an.dontShow)return;"
    r1 = b"if(!0||Tn.dontShow||an.dont)return;"
    pos1 = content.find(t1)
    if pos1 != -1:
        content[pos1:pos1+len(t1)] = r1
        patched = True

    # Target 2: !Tn.dontShow&&!an.dontShow
    t2 = b"!Tn.dontShow&&!an.dontShow"
    r2 = b"false&&!Tn.dontShow&&!an.d"
    pos2 = content.find(t2)
    if pos2 != -1:
        content[pos2:pos2+len(t2)] = r2
        patched = True

    if patched:
        with open(bin_path, "wb") as f:
            f.write(content)
        print(f"[+] Ядро {bin_path} успешно пропатчено (окна лимитов отключены).")
    else:
        print(f"[*] Ядро {bin_path} уже пропатчено или сигнатура не найдена.")
    return True

if __name__ == "__main__":
    default_target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "opencode-bin")
    target = sys.argv[1] if len(sys.argv) > 1 else default_target
    patch(target)
