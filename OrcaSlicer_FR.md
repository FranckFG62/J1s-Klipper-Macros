# Configuration OrcaSlicer — Snapmaker J1 / J1s + Klipper

Guide de configuration d'OrcaSlicer pour la Snapmaker J1 / J1s avec ce firmware Klipper.

> 🇬🇧 An English version is available in [OrcaSlicer.md](OrcaSlicer.md).

---

## 1. Profil machine

### Dimensions du plateau

| Paramètre | Valeur |
|---|---|
| Largeur (X) | 330 mm |
| Profondeur (Y) | 200 mm |
| Hauteur (Z) | 205 mm |
| Zone d'exclusion du plateau | 0x0, 10x0, 10x200, 0x200 |
| Diamètre buse | 0.4 mm |
| Diamètre filament | 1.75 mm |

### Paramètres extrudeurs

- **Nombre d'extrudeurs** : 2 (IDEX)
- **T0** : extrudeur gauche (primaire)
- **T1** : extrudeur droit

---

## 2. G-Code de démarrage (Start G-Code)

Coller dans **Machine > Start G-Code** :

```gcode
START_PRINT BED_TEMP={first_layer_bed_temperature[0]} T0_TEMP={nozzle_temperature_initial_layer[0]} T1_TEMP={nozzle_temperature_initial_layer[1]} PLATE={plate_name} SPACING=165 DENSITY_T0={filament_density[0]} DENSITY_T1={filament_density[1]}
```

> **Note** : `PLATE={plate_name} transmet le nom du plateau OrcaSlicer à la macro `START_PRINT`, qui s'en sert pour détecter le mode IDEX (voir section 4).

### Paramètres acceptés par `START_PRINT`

| Paramètre | Défaut | Description |
|---|---|---|
| `BED_TEMP` | 60 | Température du plateau (°C) |
| `T0_TEMP` | 0 | Température buse gauche T0 (°C) |
| `T1_TEMP` | 0 | Température buse droite T1 (°C) |
| `PLATE` | *(vide)* | Nom du plateau — détecte le mode IDEX |
| `SPACING` | 165 | Écartement des têtes en mode COPY (mm) |
| `DENSITY_T0` | 1.24 | Densité filament T0 (g/cm³) — pour le flush volumétrique |
| `DENSITY_T1` | 1.24 | Densité filament T1 (g/cm³) — pour le flush volumétrique |

---

## 3. G-Code de fin (End G-Code)

Coller dans **Machine > End G-Code** :

```gcode
END_PRINT
```

---

## 4. Sélection du mode IDEX par nom de plateau

`START_PRINT` détecte automatiquement le mode IDEX d'après le nom du plateau passé via `PLATE=`. Il suffit que le nom du plateau **contienne** le mot-clé correspondant (la casse est ignorée).

| Mot-clé dans le nom du plateau | Mode IDEX activé |
|---|---|
| *(aucun)* | PRIMARY — T0 si `T0_TEMP > 0`, T1 si seulement `T1_TEMP > 0` |
| `copy` | COPY — les deux têtes impriment la même pièce côte à côte |
| `mirror` | MIRROR — les deux têtes impriment en symétrie autour du centre |
| `backup` | BACKUP — T0 primaire, T1 en veille ; bascule auto sur T1 en fin de filament T0 |
| `backup_t1` | BACKUP — T1 primaire, T0 en veille ; bascule auto sur T0 en fin de filament T1 |

### Exemples de noms de plateau OrcaSlicer

| Nom suggéré | Mode |
|---|---|
| `PEI` / `Lisse` / `Texturé` | PRIMARY (T0 ou T1 selon les températures) |
| `PEI copy` | COPY |
| `PEI mirror` | MIRROR |
| `PEI backup` | BACKUP T0 → T1 |
| `PEI backup_t1` | BACKUP T1 → T0 |

> **Astuce** : Dans OrcaSlicer, les plateaux se gèrent dans **Préparation > Paramètres d'impression > Nom du plateau**. Créez un plateau par mode IDEX et nommez-le selon le tableau ci-dessus.

---

## 5. Profils filament — densités courantes

Le paramètre `DENSITY_T0` / `DENSITY_T1` est utilisé pour calculer le volume du flush pré-purge. Renseigner la densité correcte améliore la qualité de la purge lors des changements de couleur ou de matière.

| Matière | Densité (g/cm³) |
|---|---|
| PLA | 1.24 |
| PETG | 1.27 |
| ABS | 1.05 |
| ASA | 1.07 |
| TPU 95A | 1.21 |
| Nylon PA6 | 1.14 |
| PC | 1.20 |

Dans OrcaSlicer, renseigner la densité dans **Filament > Avancé > Densité**.

---

## 6. Impression bi-matière (T0 + T1) — PRIMARY

Pour imprimer avec T0 et T1 en mode PRIMARY classique :

1. Assigner les objets à T0 (`Extrudeur 1`) et T1 (`Extrudeur 2`) dans OrcaSlicer.
2. Renseigner `T0_TEMP` **et** `T1_TEMP` dans les profils filament respectifs.
3. Nommer le plateau sans mot-clé IDEX (ex. `PEI`).
4. `START_PRINT` chauffe les deux têtes et active T0 en premier.

---

## 7. Mode COPY

Les deux têtes impriment **la même pièce** simultanément, côte à côte. La tête T1 reproduit exactement les mouvements de T0 avec un décalage en X.

- **Écartement par défaut** : 165 mm (paramètre `SPACING`).
- Pour modifier : ajouter `SPACING=xxx` dans le Start G-Code.
- Concevoir la pièce dans la **moitié gauche** du plateau (≤ 175 mm en X).
- Utiliser un profil filament **identique** sur T0 et T1, ou passer `T1_TEMP` à 0 (la macro utilisera automatiquement `T0_TEMP` pour T1).

---

## 8. Mode MIRROR

Les deux têtes impriment **en miroir** par rapport au centre du plateau.

- La pièce est **symétrisée automatiquement** — importer une seule pièce.
- Concevoir dans la **moitié gauche** du plateau.
- Mêmes règles de température qu'en mode COPY.

---

## 9. Mode BACKUP

La tête de secours est maintenue à `temp_impression − 70 °C` pendant l'impression. En cas de fin de filament détectée par le capteur ADC, elle remonte automatiquement en température et reprend l'impression sans intervention.

- Assigner **tout l'objet à T0** (ou T1 selon le mode backup choisi) dans OrcaSlicer.
- Si les deux têtes manquent de filament, l'impression se met en pause normalement.

---

## 10. Conseils généraux

- **Rétraction** : avec le direct drive J1s, utiliser 0.5–1.0 mm à 30–50 mm/s.
- **Vitesse de déplacement** : max 350 mm/s, accélération max 3000 mm/s².
- **Z offset** : réglé via `CALIBRATE_Z_START` / `CALIBRATE_Z_SAVE` / `CALIBRATE_Z_END`, persisté automatiquement — ne pas modifier manuellement dans OrcaSlicer.
- **Safe distance** : les deux têtes doivent conserver un écart minimum de 21 mm.

---

## 11. Connexion à l'imprimante

Dans **OrcaSlicer > Préférences > Imprimante** :

- **Type de connexion** : Moonraker / Klipper
- **Adresse IP** : adresse de votre Raspberry Pi (ex. `http://192.168.x.x`)
- **Port** : 80 (défaut Mainsail / Moonraker)
