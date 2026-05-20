cat << 'EOF' > clean_diceware.py
import urllib.request
import unicodedata
import re
import random

print("1. Téléchargement d'un dictionnaire français...")
url = "https://raw.githubusercontent.com/Taknok/French-Wordlist/master/francais.txt"
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    content = urllib.request.urlopen(req).read().decode('utf-8', errors='ignore')
except Exception as e:
    print("Erreur de téléchargement :", e)
    exit(1)

print("2. Nettoyage (retrait des accents, tri par taille)...")
def remove_accents(input_str):
    nfkd_form = unicodedata.normalize('NFKD', input_str)
    return "".join([c for c in nfkd_form if not unicodedata.combining(c)])

dico_words = set()
for word in content.splitlines():
    clean = remove_accents(word.strip().lower())
    # On garde les mots 100% alphabétiques, entre 4 et 8 lettres
    if re.match(r'^[a-z]{4,8}$', clean):
        dico_words.add(clean)

print("3. Analyse de votre Diceware pour éviter les doublons...")
with open('diceware-wordlist.txt', 'r') as f:
    lines = f.readlines()

used_roots = set()
for line in lines:
    parts = line.strip().split()
    if len(parts) == 2:
        # Enlever les chiffres à la fin pour avoir la racine (ex: souri1 -> souri)
        root = re.sub(r'[0-9]+$', '', parts[1].lower())
        used_roots.add(root)

# La liste des mots autorisés est le dictionnaire MOINS les mots déjà dans ton diceware
available_words = list(dico_words - used_roots)
random.shuffle(available_words) # Mélange cryptographique

print("4. Remplacement des mots corrompus...")
word_idx = 0
with open('diceware-wordlist.txt', 'w') as f:
    for line in lines:
        parts = line.strip().split()
        # Si le mot finit par des chiffres et commence par des lettres (ex: sages17)
        if len(parts) == 2 and re.match(r'^[a-zA-Z]+[0-9]+$', parts[1]):
            new_word = available_words[word_idx]
            f.write(f"{parts[0]} {new_word}\n")
            word_idx += 1
        else:
            f.write(line)

print(f"-> Terminé ! {word_idx} mots remplacés avec succès par des mots français uniques.")
EOF