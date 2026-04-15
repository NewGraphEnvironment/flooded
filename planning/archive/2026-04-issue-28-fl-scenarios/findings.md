# Findings: fl_scenarios() and fl_params()

## Research (pre-existing)

All research already committed:
- `inst/research/vca_parameter_rationale.md` — verified quotes from Nagel 2014, Hall 2007
- `inst/extdata/flood_params.csv` — parameter legend with units, defaults, citations

## Key facts for scenario design

### flood_factor zones (from vca_parameter_rationale.md)
- ff=2: Rosgen flood-prone width, ~50-yr flood (active channel margin)
- ff=3: Hall 2007 best fit for historical floodplain on 10m DEM (213 field sites)
- ff=4: Reasonable functional floodplain estimate on 25m DEM
- ff=5-7: Nagel 2014 valley bottom (includes terraces, depositional areas)
- ff=7: Nagel 2014 recommendation for 30m DEM

### Defaults from flood_params.csv
- slope_threshold: 9 (percent)
- max_width: 2000 (metres)
- cost_threshold: 2500 (dimensionless)
- size_threshold: 5000 (m²)
- hole_threshold: 2500 (m²)

### Two independent width models (from flooded#25)
- bcfishpass (Thorley et al. 2021): `exp(0.307) * (area * precip / 100000) ^ 0.458`
- VCA/Hall 2007 (flooded internal): `(area ^ 0.280) * 0.196 * (precip ^ 0.355)`
