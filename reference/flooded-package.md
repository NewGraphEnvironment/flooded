# flooded: Map Floodplains from an Elevation Model and a Stream Network

Maps floodplains and unconfined valley bottoms from a digital elevation
model and a stream network with the Valley Confinement Algorithm (VCA),
keeping ground that is gentle, near a stream in both straight-line and
slope-weighted distance, and low relative to it. It reads terrain rather
than modelling flood flows, so it runs over whole watersheds for
screening and planning. Fetches an elevation model for an area, maps
preset flood levels, and attributes one floodplain to each watercourse
that shares it, carrying per-reach flags onto the ground beside each
reach. Ported from the bcfishpass lateral habitat pipeline (Python) with
origins in the USDA VCA Toolbox and BlueGeo. Under active development.

## See also

Useful links:

- <https://github.com/NewGraphEnvironment/flooded>

- <https://newgraphenvironment.github.io/flooded/>

- Report bugs at <https://github.com/NewGraphEnvironment/flooded/issues>

## Author

**Maintainer**: Allan Irvine <al@newgraphenvironment.com>
([ORCID](https://orcid.org/0000-0002-3495-2128)) (New Graph Environment
Ltd.)

Other contributors:

- Devin Cairns (Valley Confinement Algorithm (MIT license, Blue
  Geosimulation)) \[copyright holder\]

- Simon Norris (bcfishpass lateral habitat assembly (Apache 2.0))
  \[copyright holder\]

- Canadian Wildlife Federation (bcfishpass (Apache 2.0)) \[copyright
  holder\]

- Province of British Columbia (bcfishpass (Apache 2.0)) \[copyright
  holder\]

- New Graph Environment (bcfishpass (Apache 2.0)) \[copyright holder\]

- New Graph Environment Ltd. \[copyright holder, funder\]
