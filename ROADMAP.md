Sound Blocks — Development Roadmap
====================================

Generated from Feature Specification v0.1
Last updated: 2026-02-11

Table of Contents
-----------------
  0. Current State Assessment
  1. Milestone 0 — Foundation
  2. Milestone 1 — MVP Sandbox
  3. Milestone 2 — Constraints Pack
  4. Milestone 3 — Mixer v1
  5. Milestone 4 — Pipes & Breath
  6. Milestone 5 — Expansion
  A. Architecture Principles
  B. Module Map
  C. Dependency Graph


========================================================================
0. CURRENT STATE ASSESSMENT
========================================================================

What exists today (commit c0a09bb):

  IMPLEMENTED                              STATUS
  ─────────────────────────────────────    ──────
  Shape types: Circle, Rect               Done
  Body model with energy/tags/a11y        Done
  Physics: gravity, damping, integration  Done
  Collision: circle-circle, basic rect    Done
  Boundary modes: Bounce, Wrap, Clamp     Done
  UI modes: Draw, Select, Run, Inspect    Done
  Draw tools: Circle, Rect                Done
  Body selection (click + Tab cycle)      Done
  Body nudge via arrow keys               Done
  Body deletion (Delete/Backspace)        Done
  Clear all bodies                        Done
  SVG rendering with energy glow          Done
  Accessibility: ARIA labels, live log    Done
  Keyboard navigation (full)              Done
  Inspector panel (body details)          Done
  Ports: audioEvent outbound              Done
  WebAudio: collision sounds + panning    Done
  Optimized release build (elm --optimize) Done

  NOT YET IMPLEMENTED                     NEEDED BY
  ─────────────────────────────────────    ──────────
  Pan and zoom viewport                   M1
  Click-hold to move bodies (drag)        M1
  Extended shapes (hex, pent, etc.)       M5
  Materials system                        M1
  Properties panel (editable fields)      M1
  Undo / redo history                     M1
  Constraints (string/spring/weld/rope)   M2
  Grouped / welded movement               M2
  Mixer panel / master meter              M3
  Global effects (reverb, etc.)           M3
  Material-to-sound mapping               M3
  Pipe / resonator objects                M4
  Breath excitation tool                  M4
  Drill tool (resonance modification)     M4
  Energy transfer / circuit system        M5
  Save / load scenes                      M5
  Deterministic replay                    M5
  Mod scripting                           M5
  Rotation physics (rot/angVel active)    M1
  Friction physics (field exists, unused) M1
  Snap / weld placement toggle            M2
  Right-click context menus               M1


========================================================================
1. MILESTONE 0 — FOUNDATION                                  [COMPLETE]
========================================================================

Goal: Minimal runnable sim — SVG world renders, place circles and
      squares, minimal DSP feedback works.

  [x] 0.1  Elm project scaffolded with elm.json
  [x] 0.2  Model types: Body, Shape (Circle | Rect), Vec2, Bounds
  [x] 0.3  Physics step loop at 30 Hz (Time.every)
  [x] 0.4  Gravity + damping integration
  [x] 0.5  Boundary bounce
  [x] 0.6  Circle-circle collision detection + impulse resolution
  [x] 0.7  SVG rendering of bodies (circles + rects)
  [x] 0.8  Draw mode: cursor + place shape (Enter/Space)
  [x] 0.9  Select mode: Tab cycle, arrow nudge, delete
  [x] 0.10 Audio port: collision events -> WebAudio thump/click
  [x] 0.11 Compiled + release zip artifacts

Status: DONE. All M0 deliverables are shipped.


========================================================================
2. MILESTONE 1 — MVP SANDBOX                                [COMPLETE]
========================================================================

Goal: Full sandbox interaction — pan/zoom, drag-move, editable
      properties, materials affect physics, undo, complete a11y.

Estimated scope: ~15 tasks across 4 work streams.

──────────────────────────────────────────────────────────────
Stream A: Viewport & Camera
──────────────────────────────────────────────────────────────

  [ ] 1.A1  Camera model
             Add to Model.elm:
               Camera = { offset : Vec2, zoom : Float }
             Default: offset (0,0), zoom 1.0.
             SVG viewBox derived from camera state.

  [ ] 1.A2  Pan (mouse drag on background)
             New Msg: PointerDown, PointerMove, PointerUp
             When dragging on empty SVG area, update camera.offset.
             Keyboard alternative: Shift+Arrow keys pan viewport.

  [ ] 1.A3  Zoom (scroll wheel + keyboard)
             New Msg: WheelZoom Float
             Zoom centered on pointer position.
             Keyboard: +/- keys, or Ctrl+Arrow.
             Clamp zoom to [0.25 .. 4.0].

  [ ] 1.A4  World floor
             Add a static floor body (or dedicated floor boundary).
             Floor at y = world.height, rendered as a thick line/rect.
             Infinite vertical space above (no top boundary).

──────────────────────────────────────────────────────────────
Stream B: Object Manipulation
──────────────────────────────────────────────────────────────

  [ ] 1.B1  Drag-move bodies
             PointerDown on body -> begin drag.
             PointerMove -> update body.pos directly (pause velocity).
             PointerUp -> release, optionally impart throw velocity.
             Accessibility: already have arrow-nudge; drag is mouse-only
             enhancement.

  [ ] 1.B2  Spawn workflow (B key)
             B key opens shape spawner (or toggles draw mode).
             Number keys 1-9 select shape sub-type:
               1=Circle, 2=Rect (existing), 3+=future shapes.
             Space = spawn at cursor position.

  [ ] 1.B3  Rotation physics
             Activate rot/angVel fields in Body (currently stored but
             unused).
             Integrate angular velocity in Physics.Step.
             Apply torque from off-center collisions.
             Render rotation via SVG transform="rotate(...)".

  [ ] 1.B4  Friction physics
             Body.friction field exists but is unused.
             Implement tangential impulse in collision resolution.
             Surface friction affects sliding along boundaries.

──────────────────────────────────────────────────────────────
Stream C: Materials & Properties
──────────────────────────────────────────────────────────────

  [ ] 1.C1  Material type definition
             New module: Material.elm
               type alias Material =
                 { name : String
                 , density : Float
                 , friction : Float
                 , restitution : Float
                 , color : String
                 , alpha : Float
                 , soundProfile : SoundProfile
                 }
             Predefined materials: Stone, Wood, Metal, Rubber, Glass, Ice.

  [ ] 1.C2  Material panel (M key)
             New view module: View/MaterialPanel.elm
             Grid of material swatches.
             Click applies to selected body or sets default for new spawns.
             Show material name + key properties.

  [ ] 1.C3  Properties panel (P key or right-click)
             New view module: View/PropertiesPanel.elm
             Editable fields: size, position, mass/density, friction.
             Input fields that dispatch SetProperty BodyId PropertyChange.
             Number inputs with up/down arrows.
             Accessible: all fields labeled, Tab-navigable.

  [ ] 1.C4  Material-driven rendering
             Body color and opacity derived from material.
             Replace hardcoded #ff6b3d / #3d9eff with material.color.
             Energy glow still overlays on top.

──────────────────────────────────────────────────────────────
Stream D: History & Polish
──────────────────────────────────────────────────────────────

  [ ] 1.D1  Undo / Redo system
             New module: History.elm
               type alias History =
                 { past : List Model, future : List Model }
             Snapshot full model on each user action (not ticks).
             Ctrl+Z = undo, Ctrl+Shift+Z = redo.
             Cap history depth (e.g., 50 states).

  [ ] 1.D2  Right-click context menu
             Detect contextmenu event on SVG bodies.
             Show floating menu: Properties, Delete, Duplicate, Material.
             Keyboard alternative: Shift+Enter on selected body.

  [ ] 1.D3  Accessibility audit
             Verify all new panels are screen-reader navigable.
             Ensure material/property panels have proper ARIA roles.
             Test Tab order across all panels.
             Announce panel open/close via live region.

Dependencies:
  1.A1 before 1.A2, 1.A3
  1.C1 before 1.C2, 1.C4
  1.B1 requires PointerDown/Move/Up messages (shared with 1.A2)

Exit criteria:
  - Pan + zoom works with mouse and keyboard
  - Bodies can be drag-moved
  - At least 6 materials with visible + physics differences
  - Properties panel edits are reflected in simulation
  - Undo/redo works for all user actions
  - All interactions are keyboard-accessible


========================================================================
3. MILESTONE 2 — CONSTRAINTS PACK                           [COMPLETE]
========================================================================

Goal: Connect objects with physical constraints — strings, springs,
      welds, ropes — and move connected groups as units.

Estimated scope: ~10 tasks.

──────────────────────────────────────────────────────────────
Stream A: Constraint Engine
──────────────────────────────────────────────────────────────

  [ ] 2.A1  Constraint type definitions
             New module: Constraint.elm
               type ConstraintId = Int
               type ConstraintKind
                 = StringConstraint { length : Float }
                 | SpringConstraint { restLength : Float, stiffness : Float }
                 | RopeConstraint { maxLength : Float }
                 | WeldConstraint { relativeOffset : Vec2 }
               type alias Constraint =
                 { id : ConstraintId
                 , kind : ConstraintKind
                 , bodyA : BodyId
                 , bodyB : BodyId
                 }
             Add constraints : Dict ConstraintId Constraint to Model.

  [ ] 2.A2  Constraint solver
             New module: Physics/Constraints.elm
             Iterative position-based solver (Verlet-style):
               - For each constraint, compute correction vector
               - Apply proportional to inverse mass
               - Iterate 3-5 times per step for stability
             Called after collision resolution in Physics.Step.

  [ ] 2.A3  String constraint
             Fixed-length distance constraint.
             If dist(a, b) > length, pull bodies toward each other.
             If dist(a, b) < length, do nothing (slack).

  [ ] 2.A4  Spring / band constraint
             Hooke's law: F = -k * (dist - restLength).
             Apply as velocity impulse each tick.
             Configurable stiffness and optional damping.

  [ ] 2.A5  Rope / chain constraint
             Like string but with max length (not fixed).
             Visual: rendered as catenary or segmented chain.

  [ ] 2.A6  Weld constraint
             Rigid attachment: bodyB maintains fixed offset from bodyA.
             During solver, force bodyB.pos = bodyA.pos + relativeOffset.
             Share velocities (effectively one rigid group).

──────────────────────────────────────────────────────────────
Stream B: UI & Interaction
──────────────────────────────────────────────────────────────

  [ ] 2.B1  Constraints panel (C key)
             New view module: View/ConstraintPanel.elm
             Workflow: select two bodies, choose constraint type, apply.
             List active constraints with delete option.
             Keyboard: C opens panel, Tab through options.

  [ ] 2.B2  Constraint rendering
             In View/Svg.elm, render constraints as SVG lines/curves:
               String: solid thin line
               Spring: zigzag / wave path
               Rope: segmented line or catenary
               Weld: thick solid connector
             Color-coded by constraint type.

  [ ] 2.B3  Grouped movement
             When dragging a welded body, all welded bodies move together.
             Selection of one welded body highlights entire group.
             Delete constraint to un-group.

  [ ] 2.B4  Multi-select support
             Shift+Click to add body to selection.
             Selection stored as Set BodyId instead of Maybe BodyId.
             Constraints can be applied to multi-selected pairs.

Dependencies:
  M1 (drag-move, properties panel) should be complete first.
  2.A1 before all other 2.A tasks.
  2.A2 before 2.A3-2.A6.
  2.B1 requires 2.A1.
  2.B2 requires 2.A1.
  2.B3 requires 2.A6 (weld).

Exit criteria:
  - All four constraint types functional
  - Constraints visible in SVG
  - Constraints panel allows creation/deletion
  - Welded groups move as one unit
  - Multi-select works for constraint creation


========================================================================
4. MILESTONE 3 — MIXER v1
========================================================================

Goal: Audio mixer panel with master meter, 1-2 global effects, and
      refined material-to-sound mapping.

Estimated scope: ~8 tasks.

──────────────────────────────────────────────────────────────
Stream A: Audio Engine
──────────────────────────────────────────────────────────────

  [ ] 3.A1  Mixer state model
             New module: Mixer.elm
               type alias MixerState =
                 { masterVolume : Float
                 , masterMuted : Bool
                 , effects : List Effect
                 , materialSoundMap : Dict String SoundProfile
                 }
               type Effect
                 = Reverb { decay : Float, mix : Float }
                 | Delay { time : Float, feedback : Float, mix : Float }
                 | Filter { type_ : FilterType, freq : Float, q : Float }

  [ ] 3.A2  Master meter
             Track peak and RMS levels in audio.js via AnalyserNode.
             Send level data back to Elm via inbound port (optional) or
             keep meter JS-only in the mixer panel.
             Visual: vertical bar meter with peak hold.

  [ ] 3.A3  Global effects chain
             In audio.js, build effects chain:
               collision source -> effect1 -> effect2 -> master gain -> destination
             Reverb: ConvolverNode with generated impulse response.
             Delay: DelayNode with feedback loop.
             Controllable via port messages from Elm.

  [ ] 3.A4  Material-to-sound profiles
             SoundProfile per material:
               type alias SoundProfile =
                 { oscillatorType : String  -- "sine","triangle","square","sawtooth"
                 , baseFrequency : Float
                 , decayTime : Float
                 , noiseAmount : Float       -- 0..1
                 }
             Stone: low sine, short decay, some noise.
             Metal: high triangle, long decay, no noise.
             Wood: mid square, medium decay, moderate noise.
             Glass: high sine, long decay, low noise.
             Rubber: low triangle, short decay, no noise (quiet).
             Ice: mid sine, medium decay, noise burst.

──────────────────────────────────────────────────────────────
Stream B: Mixer UI
──────────────────────────────────────────────────────────────

  [ ] 3.B1  Mixer panel (X key)
             New view module: View/MixerPanel.elm
             Layout:
               - Master volume slider + mute toggle
               - Peak meter display
               - Effect slots (on/off + parameter controls)
             All controls keyboard-accessible (sliders via arrow keys).

  [ ] 3.B2  Effect parameter controls
             Each effect has collapsible parameter section.
             Sliders for continuous values (volume, decay, etc.).
             Toggle buttons for on/off.
             Changes dispatched as SetMixerParam Msg.

  [ ] 3.B3  Port protocol for mixer
             Extend Ports.elm:
               port setMasterVolume : Float -> Cmd msg
               port setEffect : Encode.Value -> Cmd msg
               port muteAudio : Bool -> Cmd msg
             audio.js handles these to update WebAudio graph.

  [ ] 3.B4  Collision sound refinement
             Collision sounds now use material's SoundProfile.
             Collisions between different materials blend profiles.
             Constraint sounds: springs produce continuous tone when
             stretched, strings produce pluck on snap-taut.

Dependencies:
  M1 (materials system) should be complete.
  3.A1 before 3.A2-3.A4.
  3.A4 requires M1 materials (1.C1).
  3.B3 before 3.A3 (port protocol needed for JS control).

Exit criteria:
  - Master meter shows audio levels
  - At least reverb + delay effects working
  - Each material produces a distinct collision sound
  - Mixer panel is fully keyboard-navigable
  - Audio can be muted without stopping simulation


========================================================================
5. MILESTONE 4 — PIPES & BREATH
========================================================================

Goal: Pipe objects as hollow resonating bodies, breath as excitation
      input, drill tool to modify resonance.

Estimated scope: ~7 tasks.

  [ ] 4.1   Pipe shape type
             New shape variant:
               Pipe { length : Float, diameter : Float, openEnds : (Bool, Bool) }
             Rendered as hollow rectangle/tube in SVG.
             Physics: treated as rect collider externally.

  [ ] 4.2   Resonance model
             Each pipe has a resonant frequency derived from length:
               f = speedOfSound / (2 * length)  (open-open)
               f = speedOfSound / (4 * length)  (open-closed)
             Store as computed property on body.

  [ ] 4.3   Breath tool
             New tool mode: BreathMode.
             Click on a pipe end to excite it.
             Produces continuous tone at resonant frequency.
             Breath strength controlled by hold duration or slider.

  [ ] 4.4   Drill tool
             New tool mode: DrillMode.
             Click on a pipe body to add a hole.
             Holes modify effective length -> change resonant frequency.
             Visual: small circles on the pipe body.

  [ ] 4.5   Pipe-to-pipe coupling
             When pipes are connected via constraints, sound transfers.
             Resonance of connected system is combination of individual
             resonances.
             Rendered: sound visualization travels along constraint lines.

  [ ] 4.6   Breath excitation audio
             In audio.js, new synthesis mode: sustained oscillator.
             Frequency from pipe resonance model.
             Amplitude envelope: attack while holding, decay on release.
             Multiple pipes can sound simultaneously.

  [ ] 4.7   Pipe accessibility
             Pipes announce their resonant frequency.
             Drill tool announces new frequency after modification.
             Inspector shows pipe-specific properties (length, holes, freq).

Dependencies:
  M2 (constraints) needed for pipe-to-pipe coupling.
  M3 (mixer) needed for audio routing.
  4.1 before 4.2-4.7.
  4.2 before 4.3, 4.4.

Exit criteria:
  - Pipes can be placed and have audible resonance
  - Breath tool produces sustained tones
  - Drill modifies pitch
  - Connected pipes share resonance


========================================================================
6. MILESTONE 5 — EXPANSION
========================================================================

Goal: Extended shape library, energy circuits, save/load, mod scripting.

Estimated scope: ~12 tasks. This milestone can be split into sub-releases.

──────────────────────────────────────────────────────────────
Stream A: Extended Shapes
──────────────────────────────────────────────────────────────

  [ ] 5.A1  Polygon shape support
             Extend Shape type:
               Poly { points : List Vec2 }
             SVG rendering via <polygon>.
             Collision: bounding circle first, then SAT for accuracy.

  [ ] 5.A2  Shape prefab library
             Predefined polygons:
               Hexagon, Pentagon, Pentagram, Parallelogram, Trapezoid.
             Each with correct vertex lists.
             Number keys 3-9 in draw mode select prefab.

  [ ] 5.A3  Polygon collision (SAT)
             Separating Axis Theorem implementation.
             New module: Physics/SAT.elm
             Handles convex polygon vs convex polygon.
             Circle vs polygon via Voronoi region method.

──────────────────────────────────────────────────────────────
Stream B: Energy Circuits
──────────────────────────────────────────────────────────────

  [ ] 5.B1  Energy transfer system
             Bodies can transfer energy through constraints.
             Energy flows from high-energy to low-energy bodies.
             Transfer rate configurable per constraint type.
             Visualize as animated glow along constraint lines.

  [ ] 5.B2  World constants panel
             Adjustable global constants:
               - Speed of sound (affects pipe resonance)
               - Energy transfer rate
               - Energy decay rate
               - Gravity magnitude and direction
             Panel accessible via G key or settings menu.

  [ ] 5.B3  Circuit-like behaviors
             Special "conductor" constraint type.
             Energy threshold triggers: when energy > N, emit event.
             Chain triggers for Rube Goldberg-style constructions.

──────────────────────────────────────────────────────────────
Stream C: Persistence
──────────────────────────────────────────────────────────────

  [ ] 5.C1  Scene serialization
             New module: Serialization.elm
             Encode/decode full Model to/from JSON.
             Bodies, constraints, materials, mixer state, camera.
             Version field for forward compatibility.

  [ ] 5.C2  Save / load UI
             Save: download JSON file.
             Load: file input, parse, replace model.
             Accessible: standard file dialogs.

  [ ] 5.C3  Deterministic replay
             Record all user Msgs with timestamps.
             Replay by feeding Msgs into update at recorded times.
             Export/import replay files (JSON array of timed Msgs).

──────────────────────────────────────────────────────────────
Stream D: Extensibility
──────────────────────────────────────────────────────────────

  [ ] 5.D1  Custom physics parts
             Thrusters: apply continuous force in a direction.
             Wheels: rotate on axis, friction-driven.
             Gears: linked rotation constraints.
             Each as a Body with special behavior tag.

  [ ] 5.D2  Mod scripting (exploratory)
             Define a simple rule language or JSON-based rule format.
             Rules: "when collision energy > X, apply force Y to body Z".
             Parse rules and integrate into update loop.
             Stretch goal: embedded Lua or expression evaluator.

Dependencies:
  5.A1 before 5.A2, 5.A3.
  5.B1 requires M2 (constraints).
  5.C1 before 5.C2, 5.C3.
  5.D1 can be developed independently.
  5.D2 is exploratory / stretch.

Exit criteria:
  - All polygon prefabs placeable and collideable
  - Energy transfers visually along constraints
  - Scenes can be saved and reloaded
  - At least one custom physics part functional


========================================================================
A. ARCHITECTURE PRINCIPLES
========================================================================

These hold across all milestones:

  1. Elm is the authoritative state engine.
     All world state lives in the Elm Model. No truth in JS.

  2. DSP is a consumer of events, not a driver.
     audio.js reacts to semantic events. It never mutates simulation
     state.

  3. Accessibility is first-class, not bolted on.
     Every new panel, tool, or interaction must be keyboard-navigable
     and screen-reader-announced from day one.

  4. Fixed-tick determinism.
     Simulation runs at a fixed tick rate (default 30 Hz).
     All physics steps are pure functions of previous state.

  5. Modularity over monolith.
     New features are new modules. Constraints are a registry.
     Materials are a dictionary. Effects are a chain.

  6. Shape rendering is DOM-native SVG.
     Every shape is a real DOM element: focusable, labelable, clickable.


========================================================================
B. MODULE MAP (projected end-state)
========================================================================

  elm/src/
    Main.elm                 Entry point, view layout, port wiring
    Model.elm                All types, Vec2 math, constructors
    Update.elm               Msg routing, keyboard/pointer handlers
    Ports.elm                Outbound ports (audioEvent, mixer control)
    History.elm              [M1] Undo/redo state management
    Material.elm             [M1] Material type + presets
    Constraint.elm           [M2] Constraint types + registry
    Mixer.elm                [M3] Mixer state + effect definitions
    Serialization.elm        [M5] JSON encode/decode for save/load

    Physics/
      Step.elm               Orchestrator: integrate, boundary, collide
      Collisions.elm         Shape-pair collision detection + response
      Energy.elm             Energy decay, kinetic energy, transfer
      Constraints.elm        [M2] Iterative constraint solver
      SAT.elm                [M5] Separating Axis Theorem for polygons

    View/
      Svg.elm                SVG body/constraint/cursor rendering
      Controls.elm           Top toolbar (modes, tools, pickers)
      Inspector.elm          Selected body detail panel
      A11y.elm               ARIA announcements, event log
      MaterialPanel.elm      [M1] Material selection grid
      PropertiesPanel.elm    [M1] Editable body properties
      ConstraintPanel.elm    [M2] Constraint creation/management
      MixerPanel.elm         [M3] Audio mixer controls

  elm/web/
    index.html               Mount point, CSS, port subscriptions
    audio.js                 WebAudio synthesis + effects chain
    styles.css               Optional external styles


========================================================================
C. DEPENDENCY GRAPH
========================================================================

  M0 (Foundation) ──── DONE
    │
    ▼
  M1 (MVP Sandbox) ─────────────────────┐
    │                                    │
    ├── 1.A: Viewport & Camera           │
    ├── 1.B: Object Manipulation         │
    ├── 1.C: Materials & Properties      │
    └── 1.D: History & Polish            │
         │                               │
         ▼                               ▼
  M2 (Constraints) ──────────── M3 (Mixer v1)
    │                              │
    │    ┌─────────────────────────┘
    │    │
    ▼    ▼
  M4 (Pipes & Breath)
    │
    ▼
  M5 (Expansion)
    ├── 5.A: Extended Shapes     (independent, can start at M2)
    ├── 5.B: Energy Circuits     (needs M2)
    ├── 5.C: Persistence         (independent, can start at M1)
    └── 5.D: Custom Parts / Mods (independent, can start at M2)

Notes on parallelism:
  - M2 and M3 can be developed in parallel after M1.
  - 5.A (polygon shapes) can begin during M2.
  - 5.C (save/load) can begin during M1 once model is stable.
  - M4 requires both M2 and M3.


End of Roadmap.
