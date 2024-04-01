# Cells

Experiments with the Odin language and cells. Think Conway's Game Of Live, but without the set rules, with my own rules and fun instead.

![screenshot](screenshot.png)

## Rules

Cells are initially spawned randomly using a weighted random function (should be tweakable at some point).

Cells with adjacent neighbours have their health increased, or stable. Cells without will have their health affected negatively, and once `Dead` will no longer be rendered.

Currently, cells spread like bacteria a bit. Some do die by chance, but eventually, they will take over.

## Some Ideas

- [ ] Sudden but temporary "dead zones", where a radious of cells is killed off and cannot be populated for a while.
- [ ] "learning", so they know to avoid certain zones
- [ ] Clusters of a certain size start to decay? Need to check more than nearest neighbours. Maybe something like each cell has a "cluster_size".

## Improvements

- [ ] Compress multiple `j, i` loops into a single loop
- [ ] Display frames per second and frame render times

