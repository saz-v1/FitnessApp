#!/usr/bin/env python3
"""Build the bundled food snapshot from the official USDA SR Legacy JSON ZIP.

Download separately from https://fdc.nal.usda.gov/download-datasets/.
This developer tool is never bundled or run by the iOS app.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile


def build(archive):
    with zipfile.ZipFile(archive) as source:
        name = next(name for name in source.namelist() if name.endswith('.json'))
        foods = json.loads(source.read(name))['SRLegacyFoods']
    result = []
    for food in foods:
        nutrients = {n['nutrient']['id']: n.get('amount') for n in food['foodNutrients']}
        kcal = nutrients.get(1008)
        if not isinstance(kcal, (int, float)) or not math.isfinite(kcal) or not 0 <= kcal <= 1000:
            continue  # Missing energy is not treated as zero.
        portions, labels = [], set()
        for portion in food.get('foodPortions', []):
            grams = portion.get('gramWeight')
            amount = portion.get('amount', 1)
            measure = portion.get('modifier') or portion.get('portionDescription')
            if not measure or not isinstance(grams, (int, float)) or not 0.01 <= grams <= 10000:
                continue
            label = f'{amount:g} {measure}'
            if label in labels:
                continue
            labels.add(label)
            portions.append({'name': label, 'grams': grams})
        entry = dict(id=food['fdcId'], name=food['description'],
                     category=food.get('foodCategory', {}).get('description', 'Other'),
                     kcalPer100g=kcal, portions=portions[:8])
        for key, nutrient_id in [('protein', 1003), ('carbohydrate', 1005), ('fat', 1004)]:
            value = nutrients.get(nutrient_id)
            entry[key] = value if isinstance(value, (int, float)) and math.isfinite(value) and 0 <= value <= 100 else None
        result.append(entry)
    result.sort(key=lambda food: (food['name'].casefold(), food['id']))
    assert len({food['id'] for food in result}) == len(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'FitnessApp/Resources/foods.json')
    args = parser.parse_args()
    result = build(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(f'{len(result)} foods, {args.output.stat().st_size:,} bytes; archive SHA256 {hashlib.sha256(args.archive.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
