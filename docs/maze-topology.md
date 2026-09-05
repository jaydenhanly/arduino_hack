# Authored Maze topology

`scripts/maze_layout.gd` owns the 24x12 ASCII cell map. Its legend is:

| Marker | Meaning |
| --- | --- |
| `#` | Connected wall cell |
| `.` | Walkable pellet cell |
| `P` | Player entrance and head |
| `1` through `8` | Ordered initial tail, nearest head first |
| `G` | Initial ghost spawn |
| `h` | Additional central ghost-area cells |
| `L`, `R` | The only wrap endpoints |

The authored map contains constrained corridors, loops and intersections. It
replaces the four randomized rectangular blocks. Seeds no longer alter walls.
Seeded respawn selection still varies deterministically within the central ghost
area. A blocked or nearby spawn waits until a safe warned spawn is possible.

`neighbor`, `neighbors`, `heading_to` and `distances` own adjacency, including
the single horizontal tunnel. Movement, buffered turns, reachable-cell queries,
ghost BFS, development routing and full-run routing use these same rules.
Off-map movement fails except moving outward from `L` or `R`, which reaches its
paired endpoint. Ghost safe-distance checks use path distance, not Manhattan
distance that would misread the tunnel.

`MazeStage.walls` remains an array of `Rect2i` for snapshot compatibility, now
one 1x1 rectangle per wall cell. It is renderer/snapshot state, not an editable
collision source. Topology owns collision. The renderer draws contiguous filled
cells with corridor-facing edges and open tunnel mouths, rather than outlined
boxes. Transition rendering deliberately consumes the new cell representation.

The existing three-second Snake-to-Maze transformation moves the player into
the authored entrance. Maze constructs the nine-cell body defined by `P12345678`.
Run identity, score, and the detached source snapshot survive. Exact incoming
Snake coordinates do not. Later stages still receive the completed Maze snapshot.

Hybrid rules remain buffered movement, one shortest-path ghost, fatal head
contact, tail attacks, warned respawn, and five points per pellet. Ghost defeats
award a bonus but never complete the stage. Normal requires 97 pellets, Demo 10.
No power pellets, frightened mode or additional ghosts were added.

The early-stage probe validates all cells, dimensions, connectivity, pellet
reachability, arbitrary incoming body relocation, tunnel movement/BFS, buffered
turns, collisions and respawn. Full rendered runs separately prove the live
handoff, score/run continuity, and both objectives without invulnerability.
