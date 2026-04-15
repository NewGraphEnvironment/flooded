# Task Plan: Enable Startup Quotes in flooded

Third `/quotes-enable` round. 25 hip-hop + 20 climate voices = 45 people, 8 research agents.

## Phase 1: Inputs
- [x] Hip-hop (25): Kanye West, Royce da 5'9", Black Thought, Ab-Soul, ASAP Rocky, Danny Brown, The Weeknd, Kenny Beats, Freddie Gibbs, Madlib, Travis Scott, Erick the Architect, Zombie Juice, Meechie Darko, Killer Mike, J Cole, Bad Bunny, Don Toliver, Aaron Frazer, Post Malone, Mac Miller, Lil Yachty, Fre$h, Mustard, IDK, Joey Bada$$
- [x] Climate (20): Katharine Hayhoe, Michael Mann, James Hansen, Gavin Schmidt, Kate Marvel, Kim Cobb, Johan Rockström, Susan Joy Hassol, Naomi Oreskes, Katharine Wilkinson, Michael Oppenheimer, Friederike Otto, Peter Kalmus, Jennifer Francis, Ben Santer, Richard Alley, Bill McKibben, David Wallace-Wells, Elizabeth Kolbert, Ayana Elizabeth Johnson

## Phase 2: Research (parallel)
- [ ] 8 agents (4 hip-hop clusters + 2 climate-science + 2 climate-writer)
- [ ] ToolSearch WebSearch/WebFetch first
- [ ] Primary-source URLs + fetch-verify

## Phase 3: Fact-check
- [ ] Tier-2 chained / book-source; spot-check direct-primary

## Phase 4: User review
- [ ] CSV veto round

## Phase 5: Infrastructure
- [ ] R/zzz.R (drift/mc template, option namespace = flooded.quote_show_source)
- [ ] data-raw/quotes_build.R + audit CSV + README
- [ ] cli to Imports

## Phase 6: Ship
- [ ] R CMD check (accept pre-existing)
- [ ] Version bump + NEWS
- [ ] Commit, PR, archive after merge
