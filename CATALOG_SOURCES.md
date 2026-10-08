# Offline reference data

## Food library

The app combines **10,625 reference entries**: **7,793 US USDA SR Legacy foods** and **2,832 UK CoFID foods**. The source selector supports All, UK and US. Overlapping food names remain separate with their own preparation, calories and nutrient values; the datasets are not averaged or treated as interchangeable. Check the entry's name, preparation and portion against the food being logged; prefer current product labels when appropriate. Both are historical datasets rather than current branded-product feeds.

### US: USDA FoodData Central SR Legacy, April 2018

The original 7,793-entry US snapshot is unchanged. It includes generic raw/cooked foods, prepared foods and some historical branded products.

- Source and licence: [USDA FoodData Central](https://fdc.nal.usda.gov/), public domain / [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- Official downloads: [USDA datasets](https://fdc.nal.usda.gov/download-datasets/).
- Archive: `FoodData_Central_sr_legacy_food_json_2018-04.zip`.
- Archive SHA-256: `0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef`.
- Retrieved 8 October 2026.
- Citation: U.S. Department of Agriculture, Agricultural Research Service, Beltsville Human Nutrition Research Center. FoodData Central. SR Legacy. Accessed 8 October 2026.

`Tools/build_food_catalog.py` creates `FitnessApp/Resources/foods.json` from a locally downloaded official archive. Nutrient 1008 supplies kcal per 100 g; 1003, 1005 and 1004 supply protein, carbohydrate and fat in grams per 100 g. Missing energy is excluded rather than replaced with zero. Missing macros stay unavailable. The USDA FDC ID and source names are preserved. Household portion gram weights and amounts come from source records; they are not guessed. Duplicate portion labels are removed, and up to eight source portions per entry are retained. The generated snapshot is approximately 2 MB.

### UK: McCance and Widdowson's CoFID, 2021

- Official source and user guide: [Composition of Foods Integrated Dataset (GOV.UK)](https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid).
- Workbook: [CoFID 2021 Excel download](https://assets.publishing.service.gov.uk/media/60538b91e90e07527df82ae4/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021..xlsx).
- Workbook SHA-256: `436e9445ef2adb2a75f3d7edd51302de3adad25385f9795fc94ba58bd030e97d`.
- Retrieved 8 October 2026. Citation: Public Health England. McCance and Widdowson's Composition of Foods Integrated Dataset, 2021.
- Licence: [Open Government Licence](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/). The [publisher's FAQ](https://fnnbri.quadram.ac.uk/help/) confirms that the downloadable data may be reused with source acknowledgement. This app includes the source and the acknowledgement: “Contains public sector information licensed under the Open Government Licence.” The separate Quadram API/extended dataset is not used.

`Tools/build_cofid_catalog.py` reads a locally downloaded workbook using `openpyxl` and produces `FitnessApp/Resources/foods-uk.json` (600,393 bytes). The app does not need Python, spreadsheet libraries or a connection. The workbook's `1.3 Proximates` table has 2,887 rows; 38 with missing/trace energy and 17 alcoholic-drink rows without a plausible published density are excluded, leaving 2,832. Nutrient `N`, blank and `Tr` markers do not become invented numeric zeroes. Missing/trace macro amounts are shown as unavailable. The separate unreviewed “old foods” file is not included.

`KCALS`, `PROT`, `CHO` and `FAT` supply energy and macros. CoFID carbohydrate definitions differ from some US tables; their published values are retained rather than recalculated. Food categories use the broad group labels in Appendix B of the user guide. No household portion weights are invented. Most entries use grams; for alcoholic beverages, the source's per-100-ml values are divided by its published specific gravity to obtain per-100-g values, with an equivalent “100 ml” portion and an explanation. Densities below 0.7 or above 1.5 are excluded, including the workbook's implausible `0.50` shandy density. Converted values are rounded to six decimal places.

UK app IDs occupy a separate namespace (`1,000,000,000 + prefix × 10,000 + suffix`) and the original CoFID code is retained separately. The workbook reuses code `13-669` for both roasted aubergine and raw watercress. Both foods are retained using deterministic IDs in a separate duplicate-code namespace derived from the code and name; uniqueness is checked when generating and loading the snapshot. USDA IDs remain unchanged, so existing saved foods keep their references. The combined JSON resources total about 2.6 MB.

Food history and saved meals store the selected ID, name, gram amount, source/code and nutrient snapshot, so a later catalogue update cannot change past calorie totals. Older snapshots without source fields continue to decode as USDA. Manual entries remain supported. No barcode lookup, allergy guarantee, clinical dietary advice or internet connection is provided.

## Exercise library

`FitnessApp/Resources/exercises.json` contains **106 original FitSwift reference entries**. Names describe generic movements; descriptions, identifiers, aliases and categorisation were authored for this project. No wger application code, descriptions, images or videos were copied. Third-party exercise licences do not apply to this original catalogue.

Entries include a stable ID, name, category, muscles, equipment, a short technique reference, search aliases and the default tracking mode (reps, time or laps). These are simple references, not personalised training prescriptions or automatic calorie-burn estimates. Users can add custom movements without a catalogue ID. Reps/laps use explicit taps; the app does not request camera or motion-sensor access.

Both libraries are read-only app resources, decoded once off the main thread and searched locally. Changes ship with app updates. Only selected foods and exercises are saved to the protected personal journal; searching a catalogue sends nothing anywhere.
