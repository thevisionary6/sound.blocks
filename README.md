# Sound Blocks

A physics sandbox where shapes collide, resonate, and make sound. Built entirely
in [Elm](https://elm-lang.org/) (0.19.1) with SVG rendering and WebAudio synthesis.

## Quick Start

Open `elm/web/index.html` in a browser. That's it -- everything runs client-side
with zero dependencies at runtime.

To rebuild from source:

```bash
cd elm
elm make src/Main.elm --optimize --output=web/elm.js
```

Requires [Elm 0.19.1](https://guide.elm-lang.org/install/elm.html). No npm, no
bundler, no build system.

## What It Does

Drop shapes onto a 2D canvas. They fall under gravity, bounce off walls and each
other, and produce sound on impact. Connect them with constraints (strings,
springs, ropes, welds). Blow into pipes to hear them resonate. Drill holes to
change the pitch. Save your scene to JSON and load it back.

### Shapes

| Tool | Key | Description |
|------|-----|-------------|
| Circle | `1` | Basic circle |
| Rectangle | `2` | Axis-aligned box |
| Pipe | `3` | Hollow resonating tube with open/closed ends |
| Triangle | `4` | Regular 3-sided polygon |
| Pentagon | `5` | Regular 5-sided polygon |
| Hexagon | `6` | Regular 6-sided polygon |
| Parallelogram | `7` | Skewed quadrilateral |
| Trapezoid | `8` | Irregular quadrilateral |

### Materials

Six materials with distinct physics and sound profiles:

| Material | Density | Bounce | Sound |
|----------|---------|--------|-------|
| Stone | 2.5 | Low | Low sine, short, gritty |
| Wood | 0.8 | Medium | Mid square, moderate |
| Metal | 7.8 | High | High triangle, ringing |
| Rubber | 1.1 | Very high | Low sine, quiet thud |
| Glass | 2.4 | Medium | High sine, bright ring |
| Ice | 0.9 | Low | Mid sine, crackling |

### Constraints

Connect any two bodies (`C` key to open panel):

- **String** -- fixed-length tether (slack below target length)
- **Spring** -- Hooke's law with configurable stiffness
- **Rope** -- like string but with maximum length
- **Weld** -- rigid attachment, shared velocity

### Modes

| Mode | Key | Purpose |
|------|-----|---------|
| Draw | `D` | Place shapes with cursor or click |
| Select | `S` | Click/Tab to select, arrow keys to nudge |
| Run | `R` / `P` | Watch simulation (P toggles pause) |
| Inspect | `I` | Tab through bodies to view details |
| Breath | `B` | Click and hold a pipe to excite it |
| Drill | `G` | Click a pipe to add a tone hole |

## Controls Reference

### Keyboard

| Key | Action |
|-----|--------|
| `D` / `S` / `I` | Switch to Draw / Select / Inspect mode |
| `P` or `R` | Toggle simulation pause |
| `1`-`8` | Select draw tool |
| `B` / `G` | Enter Breath / Drill mode |
| `Enter` / `Space` | Place shape at cursor (Draw mode) |
| `Tab` | Cycle selection through bodies |
| `Arrow keys` | Move cursor (Draw) or nudge body (Select) |
| `Delete` / `Backspace` | Delete selected body |
| `M` | Toggle material panel |
| `C` | Toggle constraints panel |
| `X` | Toggle mixer panel |
| `W` | Toggle world constants panel |
| `+` / `-` / `0` | Zoom in / out / reset |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` / `Ctrl+Y` | Redo |
| `Ctrl+S` | Save scene to file |
| `Ctrl+O` | Load scene from file |

### Mouse

- **Click background** (Draw mode) -- place shape
- **Click body** -- select it
- **Drag body** -- move it (imparts velocity on release)
- **Drag background** -- pan camera
- **Scroll wheel** -- zoom

## Panels

- **Material (M)** -- select active material for new shapes or apply to selection
- **Properties (P)** -- adjust selected body's position, size, mass, friction, bounce
- **Constraints (C)** -- create/delete links between bodies
- **Mixer (X)** -- master volume, mute, reverb (decay + mix), delay (time + feedback + mix), level meter
- **World (W)** -- gravity direction/strength, damping, energy decay rate, energy transfer rate

## Audio

Sound is synthesized in real-time via WebAudio (`audio.js`). No samples or
external audio files.

- **Collision sounds** blend the two colliding materials' profiles (oscillator
  type, base frequency, decay, noise). Energy scales volume; position controls
  stereo panning.
- **Effects chain**: source -> reverb (ConvolverNode) -> delay (with feedback)
  -> master gain -> destination. An AnalyserNode drives the mixer's level meter.
- **Breath** produces a sustained oscillator at the pipe's resonant frequency
  with 5 Hz vibrato. Release fades out over 100 ms.
- **Pipe resonance** is calculated from effective length, accounting for
  open/closed ends and drilled holes.

## Physics

- **Fixed-tick** at 30 Hz (configurable). All steps are pure functions.
- **Integration**: explicit Euler with gravity and velocity damping.
- **Collisions**: broad-phase bounding radius check, then:
  - Circle vs Circle / Rect / Pipe -- distance-based overlap
  - Polygon vs Polygon -- Separating Axis Theorem (SAT)
  - Circle vs Polygon -- SAT with Voronoi regions
  - Impulse resolution with restitution, tangential friction, angular velocity
- **Constraints**: iterative position-based solver (4 iterations per step).
  String/rope correct positions; springs apply Hooke's law as velocity impulse;
  welds enforce offset and share velocity.
- **Energy**: collision energy deposited on bodies; decays each tick
  (configurable rate); transfers through constraints from high to low.
- **Boundaries**: Bounce (default), Wrap, or Clamp modes. Floor at world bottom.

## Save / Load

Scenes are serialized as versioned JSON containing all bodies, links,
constraints, mixer state, camera, and bounds. `Ctrl+S` downloads
`sound-blocks-scene.json`; `Ctrl+O` opens a file picker to restore.

## Accessibility

- Every shape is a real SVG DOM element with `tabindex`, `role="img"`,
  `aria-label`, and `aria-roledescription`.
- All panels use `role="dialog"` with `aria-label`.
- ARIA live region announces mode changes, body placement, collisions, and tool
  selections.
- Full keyboard navigation: no interaction requires a mouse.
- Focus-visible indicators on all interactive elements.

## Architecture

```
elm/src/
  Main.elm                 Entry point, view wiring, port subscriptions
  Model.elm                All types, Vec2 math, constructors
  Update.elm               Msg routing, keyboard/pointer/mode handlers
  Ports.elm                Outbound ports (audio, mixer, breath, save/load)
  History.elm              Generic undo/redo stack (50-deep)
  Material.elm             6 material presets with SoundProfile
  Mixer.elm                Mixer state + update (volume, reverb, delay)
  Serialization.elm        JSON encode/decode for full scene state

  Physics/
    Step.elm               Orchestrator: integrate -> constrain -> boundary -> collide -> transfer -> decay
    Collisions.elm         Shape-pair detection + impulse response (integrates SAT)
    ConstraintSolver.elm   Iterative position-based solver for all link types
    Energy.elm             Decay + transfer through constraints
    Resonance.elm          Pipe resonant frequency from length, ends, holes
    SAT.elm                Separating Axis Theorem for convex polygons

  View/
    Svg.elm                SVG body/constraint/cursor rendering
    Controls.elm           Top toolbar (modes, tools, panels, zoom)
    Inspector.elm          Selected body detail readout
    A11y.elm               ARIA announcements + event log
    MaterialPanel.elm      Material selection grid
    PropertiesPanel.elm    Editable body properties
    ConstraintPanel.elm    Link creation / management
    MixerPanel.elm         Audio mixer controls
    WorldPanel.elm         Adjustable physics constants

elm/web/
  index.html               Mount point, port subscriptions, save/load JS
  audio.js                 WebAudio synthesis + effects chain
  styles.css               Base styles + focus indicators
  elm.js                   Compiled output (not committed to source)
```

### Design Principles

1. **Elm owns all state.** The JS layer (`audio.js`) is a consumer of events,
   never a source of truth.
2. **Accessibility is structural.** Every shape is a focusable DOM node. Screen
   readers work without extra effort.
3. **Fixed-tick determinism.** Physics runs at a constant rate; all steps are
   pure. Same inputs always produce the same outputs.
4. **Zero external dependencies at runtime.** Fonts are loaded from Google Fonts
   for aesthetics but the app works without them.

## Dependencies

**Build time only:**

- [Elm 0.19.1](https://elm-lang.org/)
- elm/browser, elm/core, elm/html, elm/json, elm/svg, elm/time (standard library)

**Runtime:** None. Pure client-side HTML + JS.

## Project Stats

- ~5,500 lines of Elm across 22 modules
- ~450 lines of JavaScript (audio engine)
- ~170 lines of HTML/CSS
- 8 shape types, 6 materials, 4 constraint types, 6 interaction modes
- 5 UI panels, full keyboard navigation
- JSON scene persistence with versioned format

## License

See repository for license information.
