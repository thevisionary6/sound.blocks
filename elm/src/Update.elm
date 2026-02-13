module Update exposing (Msg(..), subscriptions, update)

import Browser.Events
import Dict
import History
import Json.Decode as Decode
import Material
import Mixer exposing (MixerMsg(..), updateMixer)
import Model exposing (..)
import Serialization
import Physics.Resonance
import Physics.Step
import Ports
import Time
import View.PropertiesPanel exposing (PropertyChange(..))
import View.Svg
import View.WorldPanel exposing (WorldChange(..))


type Msg
    = Tick Time.Posix
    | KeyDown String Bool Bool
    | ToggleRun
    | ToggleMode
    | Clear
    | SvgMsg View.Svg.Msg
    | PointerMove Float Float
    | PointerUp
    | WheelZoom Float
    | TogglePanel Panel
    | SelectMaterial String
    | AdjustProperty PropertyChange
    | Undo
    | Redo
    | ZoomIn
    | ZoomOut
    | ZoomReset
    | SetDrawTool DrawTool
    | SetBoundaryMode BoundaryMode
    | SetCollisionMode CollisionMode
    | StartLinkCreation LinkKind
    | CancelLinkCreation
    | DeleteLink LinkId
    | MixerUpdate MixerMsg
    | BreathStart BodyId
    | BreathStop
    | DrillHole BodyId Float
    | SetMode UiMode
    | AdjustWorld WorldChange
    | SaveScene
    | LoadScene
    | SceneLoaded String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick _ ->
            if model.sim.running then
                let
                    sim =
                        model.sim

                    result =
                        Physics.Step.step model.constraints model.bounds sim.stepCount model.links model.bodies

                    cmds =
                        List.map (collisionToAudioCmd model.bodies) result.events
                in
                ( { model
                    | bodies = result.bodies
                    , sim = { sim | stepCount = sim.stepCount + 1 }
                    , log = updateLogWithEvents result.events model.log
                  }
                , Cmd.batch cmds
                )

            else
                ( model, Cmd.none )

        ToggleRun ->
            ( announce
                (if model.sim.running then
                    "Paused."

                 else
                    "Running."
                )
                { model | sim = setSimRunning (not model.sim.running) model.sim }
            , Cmd.none
            )

        ToggleMode ->
            let
                ui =
                    model.ui

                newMode =
                    case ui.mode of
                        DrawMode ->
                            SelectMode

                        SelectMode ->
                            RunMode

                        RunMode ->
                            InspectMode

                        InspectMode ->
                            BreathMode

                        BreathMode ->
                            DrillMode

                        DrillMode ->
                            DrawMode
            in
            ( announce (modeAnnouncement newMode)
                { model | ui = { ui | mode = newMode } }
            , Cmd.none
            )

        Clear ->
            let
                snapped =
                    pushSnapshot model
            in
            ( announce "All bodies cleared."
                { snapped
                    | bodies = Dict.empty
                    , nextId = 1
                    , links = Dict.empty
                    , nextLinkId = 1
                    , ui = setSelected Nothing snapped.ui
                }
            , Cmd.none
            )

        SvgMsg svgMsg ->
            handleSvgMsg svgMsg model

        PointerMove cx cy ->
            handlePointerMove cx cy model

        PointerUp ->
            let
                ui =
                    model.ui

                breathCmd =
                    case ui.breathTarget of
                        Just _ ->
                            Ports.sendBreathEvent
                                { action = "stop"
                                , frequency = 0
                                , bodyId = -1
                                , x = 0
                                , materialName = ""
                                }

                        Nothing ->
                            Cmd.none
            in
            ( { model | ui = { ui | pointer = Idle, breathTarget = Nothing } }
            , breathCmd
            )

        WheelZoom deltaY ->
            let
                camera =
                    model.camera

                factor =
                    if deltaY < 0 then
                        1.1

                    else
                        1 / 1.1

                newZoom =
                    clamp 0.25 4.0 (camera.zoom * factor)
            in
            ( { model | camera = { camera | zoom = newZoom } }, Cmd.none )

        TogglePanel panel ->
            let
                ui =
                    model.ui

                newPanel =
                    if ui.panel == panel then
                        NoPanel

                    else
                        panel
            in
            ( { model | ui = { ui | panel = newPanel } }, Cmd.none )

        SelectMaterial matName ->
            let
                ui =
                    model.ui
            in
            ( announce (matName ++ " material selected.")
                { model | ui = { ui | activeMaterial = matName } }
            , Cmd.none
            )

        AdjustProperty change ->
            ( applyPropertyChange change model, Cmd.none )

        Undo ->
            let
                current =
                    makeSnapshot model
            in
            case History.undo current model.history of
                Just ( snap, newHistory ) ->
                    ( announce "Undo."
                        { model
                            | bodies = snap.bodies
                            , nextId = snap.nextId
                            , links = snap.links
                            , nextLinkId = snap.nextLinkId
                            , history = newHistory
                        }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        Redo ->
            let
                current =
                    makeSnapshot model
            in
            case History.redo current model.history of
                Just ( snap, newHistory ) ->
                    ( announce "Redo."
                        { model
                            | bodies = snap.bodies
                            , nextId = snap.nextId
                            , links = snap.links
                            , nextLinkId = snap.nextLinkId
                            , history = newHistory
                        }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        ZoomIn ->
            let
                camera =
                    model.camera

                newZoom =
                    clamp 0.25 4.0 (camera.zoom * 1.15)
            in
            ( { model | camera = { camera | zoom = newZoom } }, Cmd.none )

        ZoomOut ->
            let
                camera =
                    model.camera

                newZoom =
                    clamp 0.25 4.0 (camera.zoom / 1.15)
            in
            ( { model | camera = { camera | zoom = newZoom } }, Cmd.none )

        ZoomReset ->
            ( { model | camera = { offset = vecZero, zoom = 1.0 } }, Cmd.none )

        SetDrawTool tool ->
            let
                ui =
                    model.ui

                toolName =
                    case tool of
                        CircleTool ->
                            "Circle tool selected."

                        RectTool ->
                            "Rectangle tool selected."

                        PipeTool ->
                            "Pipe tool selected."

                        TriangleTool ->
                            "Triangle tool selected."

                        PentagonTool ->
                            "Pentagon tool selected."

                        HexagonTool ->
                            "Hexagon tool selected."

                        ParallelogramTool ->
                            "Parallelogram tool selected."

                        TrapezoidTool ->
                            "Trapezoid tool selected."
            in
            ( announce toolName { model | ui = { ui | drawTool = tool } }
            , Cmd.none
            )

        SetBoundaryMode mode ->
            let
                constraints =
                    model.constraints

                label =
                    case mode of
                        Bounce ->
                            "Boundary: Bounce"

                        Wrap ->
                            "Boundary: Wrap"

                        Clamp ->
                            "Boundary: Clamp"
            in
            ( announce label { model | constraints = { constraints | boundaryMode = mode } }
            , Cmd.none
            )

        SetCollisionMode mode ->
            let
                constraints =
                    model.constraints

                label =
                    case mode of
                        NoCollisions ->
                            "Collisions: Off"

                        SimpleCollisions ->
                            "Collisions: Simple"

                        EnergeticCollisions ->
                            "Collisions: Energetic"
            in
            ( announce label { model | constraints = { constraints | collisionMode = mode } }
            , Cmd.none
            )

        KeyDown key ctrl shift ->
            handleKey key ctrl shift model

        StartLinkCreation kind ->
            let
                ui =
                    model.ui
            in
            ( announce "Click the first body."
                { model | ui = { ui | linkCreation = PickingFirst kind } }
            , Cmd.none
            )

        CancelLinkCreation ->
            let
                ui =
                    model.ui
            in
            ( announce "Constraint creation cancelled."
                { model | ui = { ui | linkCreation = NotCreating } }
            , Cmd.none
            )

        DeleteLink linkId ->
            let
                snapped =
                    pushSnapshot model
            in
            ( announce "Constraint deleted."
                { snapped | links = Dict.remove linkId snapped.links }
            , Cmd.none
            )

        MixerUpdate mixerMsg ->
            let
                newMixer =
                    updateMixer mixerMsg model.mixer
            in
            ( { model | mixer = newMixer }
            , sendMixerState newMixer
            )

        BreathStart bodyId ->
            case Dict.get bodyId model.bodies of
                Just body ->
                    case body.shape of
                        Pipe { length, openEnds, holes } ->
                            let
                                freq =
                                    Physics.Resonance.pipeResonantFreq length openEnds holes

                                ui =
                                    model.ui
                            in
                            ( announce ("Breathing pipe at " ++ String.fromInt (round freq) ++ " Hz")
                                { model | ui = { ui | breathTarget = Just bodyId } }
                            , Ports.sendBreathEvent
                                { action = "start"
                                , frequency = freq
                                , bodyId = bodyId
                                , x = body.pos.x
                                , materialName = body.materialName
                                }
                            )

                        _ ->
                            ( announce "Not a pipe." model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        BreathStop ->
            let
                ui =
                    model.ui
            in
            ( { model | ui = { ui | breathTarget = Nothing } }
            , Ports.sendBreathEvent
                { action = "stop"
                , frequency = 0
                , bodyId = -1
                , x = 0
                , materialName = ""
                }
            )

        DrillHole bodyId holePos ->
            let
                snapped =
                    pushSnapshot model

                newBodies =
                    Dict.update bodyId
                        (Maybe.map
                            (\body ->
                                case body.shape of
                                    Pipe pipe ->
                                        let
                                            newHoles =
                                                pipe.holes ++ [ holePos ]

                                            newFreq =
                                                Physics.Resonance.pipeResonantFreq pipe.length pipe.openEnds newHoles
                                        in
                                        { body
                                            | shape = Pipe { pipe | holes = newHoles }
                                            , a11y =
                                                { name = body.a11y.name
                                                , description =
                                                    body.a11y.description
                                                        ++ ", "
                                                        ++ String.fromInt (List.length newHoles)
                                                        ++ " holes, "
                                                        ++ String.fromInt (round newFreq)
                                                        ++ " Hz"
                                                }
                                        }

                                    _ ->
                                        body
                            )
                        )
                        snapped.bodies
            in
            ( announce "Hole drilled."
                { snapped | bodies = newBodies }
            , Cmd.none
            )

        SetMode newMode ->
            let
                ui =
                    model.ui
            in
            ( announce (modeAnnouncement newMode)
                { model | ui = { ui | mode = newMode } }
            , Cmd.none
            )

        AdjustWorld worldChange ->
            ( applyWorldChange worldChange model, Cmd.none )

        SaveScene ->
            ( announce "Scene saved."
                model
            , Ports.sendSaveScene (Serialization.encodeScene model)
            )

        LoadScene ->
            ( announce "Loading scene..."
                model
            , Ports.requestLoadScene ()
            )

        SceneLoaded jsonStr ->
            case Decode.decodeString Serialization.decodeScene jsonStr of
                Ok scene ->
                    let
                        ui =
                            model.ui

                        stopBreathCmd =
                            case ui.breathTarget of
                                Just _ ->
                                    Ports.sendBreathEvent
                                        { action = "stop"
                                        , frequency = 0
                                        , bodyId = -1
                                        , x = 0
                                        , materialName = ""
                                        }

                                Nothing ->
                                    Cmd.none
                    in
                    ( announce
                        ("Scene loaded. "
                            ++ String.fromInt (Dict.size scene.bodies)
                            ++ " bodies."
                        )
                        { model
                            | bodies = scene.bodies
                            , nextId = scene.nextId
                            , links = scene.links
                            , nextLinkId = scene.nextLinkId
                            , constraints = scene.constraints
                            , mixer = scene.mixer
                            , camera = scene.camera
                            , bounds = scene.bounds
                            , history = History.empty
                            , sim = { running = False, fixedDt = model.sim.fixedDt, stepCount = 0 }
                            , ui = { ui | breathTarget = Nothing, selected = Nothing }
                        }
                    , Cmd.batch [ sendMixerState scene.mixer, stopBreathCmd ]
                    )

                Err _ ->
                    ( announce "Failed to load scene: invalid format."
                        model
                    , Cmd.none
                    )



-- SVG MSG HANDLING


handleSvgMsg : View.Svg.Msg -> Model -> ( Model, Cmd Msg )
handleSvgMsg svgMsg model =
    case model.ui.linkCreation of
        PickingFirst kind ->
            handleLinkPick svgMsg kind model

        PickingSecond kind bodyA ->
            handleLinkPickSecond svgMsg kind bodyA model

        NotCreating ->
            handleSvgMsgNormal svgMsg model


handleLinkPick : View.Svg.Msg -> LinkKind -> Model -> ( Model, Cmd Msg )
handleLinkPick svgMsg kind model =
    case svgMsg of
        View.Svg.PointerDownOnBody id _ _ ->
            let
                ui =
                    model.ui
            in
            ( announce ("Body " ++ String.fromInt id ++ " selected. Click second body.")
                { model | ui = { ui | linkCreation = PickingSecond kind id, selected = Just id } }
            , Cmd.none
            )

        View.Svg.ClickBody _ ->
            ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


handleLinkPickSecond : View.Svg.Msg -> LinkKind -> BodyId -> Model -> ( Model, Cmd Msg )
handleLinkPickSecond svgMsg kind bodyA model =
    case svgMsg of
        View.Svg.PointerDownOnBody bodyB _ _ ->
            if bodyA == bodyB then
                ( model, Cmd.none )

            else
                createLink kind bodyA bodyB model

        View.Svg.ClickBody _ ->
            ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


createLink : LinkKind -> BodyId -> BodyId -> Model -> ( Model, Cmd Msg )
createLink kind bodyA bodyB model =
    case ( Dict.get bodyA model.bodies, Dict.get bodyB model.bodies ) of
        ( Just a, Just b ) ->
            let
                delta =
                    vecSub b.pos a.pos

                dist =
                    vecLen delta

                resolvedKind =
                    case kind of
                        StringLink _ ->
                            StringLink { length = dist }

                        SpringLink _ ->
                            SpringLink { restLength = dist, stiffness = 100 }

                        RopeLink _ ->
                            RopeLink { maxLength = dist * 1.5 }

                        WeldLink _ ->
                            WeldLink { relativeOffset = delta }

                newLink =
                    { id = model.nextLinkId
                    , kind = resolvedKind
                    , bodyA = bodyA
                    , bodyB = bodyB
                    }

                ui =
                    model.ui

                snapped =
                    pushSnapshot model
            in
            ( announce "Constraint created."
                { snapped
                    | links = Dict.insert model.nextLinkId newLink snapped.links
                    , nextLinkId = model.nextLinkId + 1
                    , ui = { ui | linkCreation = NotCreating }
                }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


handleSvgMsgNormal : View.Svg.Msg -> Model -> ( Model, Cmd Msg )
handleSvgMsgNormal svgMsg model =
    case svgMsg of
        View.Svg.ClickBody id ->
            case model.ui.mode of
                DrillMode ->
                    handleDrillClick id model

                _ ->
                    let
                        ui =
                            model.ui

                        bodyName =
                            case Dict.get id model.bodies of
                                Just body ->
                                    bodyLabel body ++ " selected."

                                Nothing ->
                                    "Body selected."
                    in
                    ( announce bodyName
                        { model | ui = { ui | selected = Just id, mode = SelectMode } }
                    , Cmd.none
                    )

        View.Svg.PointerDownOnBody id cx cy ->
            case model.ui.mode of
                BreathMode ->
                    update (BreathStart id) model

                DrillMode ->
                    ( model, Cmd.none )

                _ ->
                    let
                        ui =
                            model.ui

                        snapped =
                            pushSnapshot model
                    in
                    ( { snapped
                        | ui =
                            { ui
                                | pointer = DraggingBody id { x = cx, y = cy }
                                , selected = Just id
                            }
                      }
                    , Cmd.none
                    )

        View.Svg.PointerDownOnBg ox oy cx cy ->
            case model.ui.mode of
                DrawMode ->
                    let
                        worldPos =
                            screenToWorld model.camera { x = ox, y = oy }
                    in
                    ( placeShapeAt worldPos model, Cmd.none )

                _ ->
                    let
                        ui =
                            model.ui
                    in
                    ( { model | ui = { ui | pointer = Panning { x = cx, y = cy } } }
                    , Cmd.none
                    )

        View.Svg.NoOp ->
            ( model, Cmd.none )



handleDrillClick : BodyId -> Model -> ( Model, Cmd Msg )
handleDrillClick id model =
    case Dict.get id model.bodies of
        Just body ->
            case body.shape of
                Pipe pipe ->
                    let
                        existingCount =
                            List.length pipe.holes

                        newHolePos =
                            toFloat (existingCount + 1) / toFloat (existingCount + 2)
                    in
                    update (DrillHole id newHolePos) model

                _ ->
                    ( announce "Not a pipe. Drill only works on pipes." model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )



-- POINTER HANDLING


handlePointerMove : Float -> Float -> Model -> ( Model, Cmd Msg )
handlePointerMove cx cy model =
    let
        ui =
            model.ui
    in
    case ui.pointer of
        Idle ->
            ( model, Cmd.none )

        DraggingBody id lastPos ->
            let
                dx =
                    (cx - lastPos.x) / model.camera.zoom

                dy =
                    (cy - lastPos.y) / model.camera.zoom

                -- Scale delta into a fling velocity (pixels per frame at 30Hz)
                flingScale =
                    toFloat model.constraints.tickRateHz

                dragVel =
                    { x = dx * flingScale, y = dy * flingScale }

                newBodies =
                    Dict.update id
                        (Maybe.map
                            (\body ->
                                { body
                                    | pos = { x = body.pos.x + dx, y = body.pos.y + dy }
                                    , vel = dragVel
                                }
                            )
                        )
                        model.bodies
            in
            ( { model
                | bodies = newBodies
                , ui = { ui | pointer = DraggingBody id { x = cx, y = cy } }
              }
            , Cmd.none
            )

        Panning lastPos ->
            let
                dx =
                    (cx - lastPos.x) / model.camera.zoom

                dy =
                    (cy - lastPos.y) / model.camera.zoom

                camera =
                    model.camera

                newOffset =
                    { x = camera.offset.x - dx
                    , y = camera.offset.y - dy
                    }
            in
            ( { model
                | camera = { camera | offset = newOffset }
                , ui = { ui | pointer = Panning { x = cx, y = cy } }
              }
            , Cmd.none
            )



-- HISTORY HELPERS


makeSnapshot : Model -> Snapshot
makeSnapshot model =
    { bodies = model.bodies
    , nextId = model.nextId
    , links = model.links
    , nextLinkId = model.nextLinkId
    }


pushSnapshot : Model -> Model
pushSnapshot model =
    { model | history = History.push (makeSnapshot model) model.history }



-- PROPERTY CHANGES


applyPropertyChange : PropertyChange -> Model -> Model
applyPropertyChange change model =
    case model.ui.selected of
        Nothing ->
            model

        Just id ->
            let
                newBodies =
                    Dict.update id (Maybe.map (applyChange change)) model.bodies
            in
            pushSnapshot { model | bodies = newBodies }


applyChange : PropertyChange -> Body -> Body
applyChange change body =
    case change of
        AdjPosX d ->
            { body | pos = { x = body.pos.x + d, y = body.pos.y } }

        AdjPosY d ->
            { body | pos = { x = body.pos.x, y = body.pos.y + d } }

        AdjRadius d ->
            case body.shape of
                Circle { r } ->
                    { body | shape = Circle { r = max 5 (r + d) } }

                _ ->
                    body

        AdjWidth d ->
            case body.shape of
                Rect { w, h } ->
                    { body | shape = Rect { w = max 10 (w + d), h = h } }

                Pipe pipe ->
                    { body | shape = Pipe { pipe | length = max 20 (pipe.length + d) } }

                _ ->
                    body

        AdjHeight d ->
            case body.shape of
                Rect { w, h } ->
                    { body | shape = Rect { w = w, h = max 10 (h + d) } }

                Pipe pipe ->
                    { body | shape = Pipe { pipe | diameter = max 8 (pipe.diameter + d) } }

                _ ->
                    body

        AdjMass d ->
            { body | mass = max 0.1 (body.mass + d) }

        AdjFriction d ->
            { body | friction = clamp 0 1 (body.friction + d) }

        AdjRestitution d ->
            { body | restitution = clamp 0 1 (body.restitution + d) }



-- KEY HANDLING


handleKey : String -> Bool -> Bool -> Model -> ( Model, Cmd Msg )
handleKey key ctrl shift model =
    if ctrl && key == "z" && not shift then
        update Undo model

    else if ctrl && key == "z" && shift then
        update Redo model

    else if ctrl && key == "y" then
        update Redo model

    else if ctrl && key == "s" then
        update SaveScene model

    else if ctrl && key == "o" then
        update LoadScene model

    else
        handleNonModifierKey key model


handleNonModifierKey : String -> Model -> ( Model, Cmd Msg )
handleNonModifierKey key model =
    case key of
        "p" ->
            update ToggleRun model

        "d" ->
            let
                ui =
                    model.ui
            in
            ( announce "Draw mode." { model | ui = { ui | mode = DrawMode } }, Cmd.none )

        "s" ->
            let
                ui =
                    model.ui
            in
            ( announce "Select mode." { model | ui = { ui | mode = SelectMode } }, Cmd.none )

        "r" ->
            update ToggleRun model

        "i" ->
            let
                ui =
                    model.ui
            in
            ( announce "Inspect mode." { model | ui = { ui | mode = InspectMode } }, Cmd.none )

        "1" ->
            update (SetDrawTool CircleTool) model

        "2" ->
            update (SetDrawTool RectTool) model

        "3" ->
            update (SetDrawTool PipeTool) model

        "4" ->
            update (SetDrawTool TriangleTool) model

        "5" ->
            update (SetDrawTool PentagonTool) model

        "6" ->
            update (SetDrawTool HexagonTool) model

        "7" ->
            update (SetDrawTool ParallelogramTool) model

        "8" ->
            update (SetDrawTool TrapezoidTool) model

        "b" ->
            update (SetMode BreathMode) model

        "g" ->
            update (SetMode DrillMode) model

        "m" ->
            update (TogglePanel MaterialPanel) model

        "c" ->
            update (TogglePanel ConstraintPanel) model

        "x" ->
            update (TogglePanel MixerPanel) model

        "w" ->
            update (TogglePanel WorldPanel) model

        "+" ->
            update ZoomIn model

        "=" ->
            update ZoomIn model

        "-" ->
            update ZoomOut model

        "0" ->
            update ZoomReset model

        _ ->
            case model.ui.mode of
                DrawMode ->
                    ( handleDrawKey key model, Cmd.none )

                SelectMode ->
                    ( handleSelectKey key model, Cmd.none )

                RunMode ->
                    ( model, Cmd.none )

                InspectMode ->
                    ( handleInspectKey key model, Cmd.none )

                BreathMode ->
                    if key == "Escape" then
                        update (SetMode DrawMode) model

                    else
                        ( model, Cmd.none )

                DrillMode ->
                    if key == "Escape" then
                        update (SetMode DrawMode) model

                    else
                        ( model, Cmd.none )


handleDrawKey : String -> Model -> Model
handleDrawKey key model =
    let
        step =
            20

        ui =
            model.ui

        cursor =
            ui.cursor

        bounds =
            model.bounds
    in
    case key of
        "ArrowUp" ->
            { model
                | ui =
                    { ui
                        | cursor =
                            { cursor
                                | pos = { x = cursor.pos.x, y = max 20 (cursor.pos.y - step) }
                            }
                    }
            }

        "ArrowDown" ->
            { model
                | ui =
                    { ui
                        | cursor =
                            { cursor
                                | pos = { x = cursor.pos.x, y = min (bounds.height - 20) (cursor.pos.y + step) }
                            }
                    }
            }

        "ArrowLeft" ->
            { model
                | ui =
                    { ui
                        | cursor =
                            { cursor
                                | pos = { x = max 20 (cursor.pos.x - step), y = cursor.pos.y }
                            }
                    }
            }

        "ArrowRight" ->
            { model
                | ui =
                    { ui
                        | cursor =
                            { cursor
                                | pos = { x = min (bounds.width - 20) (cursor.pos.x + step), y = cursor.pos.y }
                            }
                    }
            }

        "Enter" ->
            placeShapeAt model.ui.cursor.pos model

        " " ->
            placeShapeAt model.ui.cursor.pos model

        "Tab" ->
            announce "Select mode. Tab through bodies, arrow keys nudge selected body."
                { model | ui = { ui | mode = SelectMode } }

        "Escape" ->
            model

        _ ->
            model


placeShapeAt : Vec2 -> Model -> Model
placeShapeAt pos model =
    let
        ui =
            model.ui

        matName =
            ui.activeMaterial

        newBody =
            case ui.drawTool of
                CircleTool ->
                    makeCircle model.nextId pos 20 matName

                RectTool ->
                    makeRect model.nextId pos 40 30 matName

                PipeTool ->
                    makePipe model.nextId pos 80 16 matName

                TriangleTool ->
                    makePoly model.nextId pos (trianglePoints 20) "Triangle" matName

                PentagonTool ->
                    makePoly model.nextId pos (pentagonPoints 20) "Pentagon" matName

                HexagonTool ->
                    makePoly model.nextId pos (hexagonPoints 20) "Hexagon" matName

                ParallelogramTool ->
                    makePoly model.nextId pos (parallelogramPoints 40 30) "Parallelogram" matName

                TrapezoidTool ->
                    makePoly model.nextId pos (trapezoidPoints 40 30) "Trapezoid" matName

        newBodies =
            Dict.insert model.nextId newBody model.bodies

        snapped =
            pushSnapshot model
    in
    announce
        (bodyLabel newBody
            ++ " placed at "
            ++ String.fromInt (round pos.x)
            ++ ", "
            ++ String.fromInt (round pos.y)
            ++ ". "
            ++ String.fromInt (Dict.size newBodies)
            ++ " bodies total."
        )
        { snapped
            | bodies = newBodies
            , nextId = model.nextId + 1
        }


handleSelectKey : String -> Model -> Model
handleSelectKey key model =
    let
        ui =
            model.ui
    in
    case key of
        "Tab" ->
            let
                bodyIds =
                    Dict.keys model.bodies

                nextSelected =
                    case ui.selected of
                        Nothing ->
                            List.head bodyIds

                        Just current ->
                            let
                                afterCurrent =
                                    List.filter (\id -> id > current) bodyIds
                            in
                            case afterCurrent of
                                next :: _ ->
                                    Just next

                                [] ->
                                    List.head bodyIds
            in
            announce
                (case nextSelected of
                    Just id ->
                        case Dict.get id model.bodies of
                            Just body ->
                                bodyLabel body
                                    ++ " at "
                                    ++ String.fromInt (round body.pos.x)
                                    ++ ", "
                                    ++ String.fromInt (round body.pos.y)

                            Nothing ->
                                "Selected body " ++ String.fromInt id

                    Nothing ->
                        "No bodies to select."
                )
                { model | ui = { ui | selected = nextSelected } }

        "ArrowUp" ->
            nudgeSelected { x = 0, y = -15 } model

        "ArrowDown" ->
            nudgeSelected { x = 0, y = 15 } model

        "ArrowLeft" ->
            nudgeSelected { x = -15, y = 0 } model

        "ArrowRight" ->
            nudgeSelected { x = 15, y = 0 } model

        "Delete" ->
            case ui.selected of
                Just id ->
                    let
                        name =
                            Dict.get id model.bodies
                                |> Maybe.map bodyLabel
                                |> Maybe.withDefault ("Body " ++ String.fromInt id)

                        snapped =
                            pushSnapshot model

                        newBodies =
                            Dict.remove id snapped.bodies

                        newLinks =
                            Dict.filter
                                (\_ link -> link.bodyA /= id && link.bodyB /= id)
                                snapped.links
                    in
                    announce
                        (name ++ " deleted. " ++ String.fromInt (Dict.size newBodies) ++ " bodies remaining.")
                        { snapped
                            | bodies = newBodies
                            , links = newLinks
                            , ui = { ui | selected = Nothing }
                        }

                Nothing ->
                    model

        "Backspace" ->
            handleSelectKey "Delete" model

        "Escape" ->
            announce "Draw mode. Arrow keys move cursor, Enter places a shape."
                { model | ui = { ui | mode = DrawMode, selected = Nothing } }

        _ ->
            model


handleInspectKey : String -> Model -> Model
handleInspectKey key model =
    let
        ui =
            model.ui
    in
    case key of
        "Tab" ->
            handleSelectKey "Tab" model

        "Escape" ->
            announce "Draw mode."
                { model | ui = { ui | mode = DrawMode } }

        _ ->
            model


nudgeSelected : Vec2 -> Model -> Model
nudgeSelected impulse model =
    case model.ui.selected of
        Just id ->
            let
                newBodies =
                    Dict.update id
                        (Maybe.map
                            (\body ->
                                { body
                                    | vel =
                                        { x = body.vel.x + impulse.x * 10
                                        , y = body.vel.y + impulse.y * 10
                                        }
                                }
                            )
                        )
                        model.bodies
            in
            { model | bodies = newBodies }

        Nothing ->
            announce "No body selected to nudge." model



-- HELPERS


setSimRunning : Bool -> SimState -> SimState
setSimRunning running sim =
    { sim | running = running }


setSelected : Maybe BodyId -> UiState -> UiState
setSelected sel ui =
    { ui | selected = sel }


modeAnnouncement : UiMode -> String
modeAnnouncement mode =
    case mode of
        DrawMode ->
            "Draw mode. Arrow keys move cursor, Enter places a shape."

        SelectMode ->
            "Select mode. Tab through bodies, arrow keys nudge selected body."

        RunMode ->
            "Run mode. Simulation running, press P to pause."

        InspectMode ->
            "Inspect mode. Tab through bodies to view details."

        BreathMode ->
            "Breath mode. Click and hold a pipe to excite it."

        DrillMode ->
            "Drill mode. Click a pipe to add a hole."



-- EVENT LOG


updateLogWithEvents : List CollisionEvent -> EventLog -> EventLog
updateLogWithEvents events log =
    case events of
        [] ->
            log

        first :: _ ->
            { log
                | lastCollision = Just first
                , announcements =
                    List.take 20
                        (List.map collisionAnnouncement events ++ log.announcements)
            }


collisionAnnouncement : CollisionEvent -> String
collisionAnnouncement event =
    let
        targetStr =
            case event.b of
                BodyTarget id ->
                    "Body " ++ String.fromInt id

                BoundaryTarget ->
                    "boundary"
    in
    "Collision: Body "
        ++ String.fromInt event.a
        ++ " hit "
        ++ targetStr
        ++ " (energy: "
        ++ String.fromInt (round event.energy)
        ++ ")"


collisionToAudioCmd : Dict.Dict BodyId Body -> CollisionEvent -> Cmd Msg
collisionToAudioCmd bodies event =
    let
        bId =
            case event.b of
                BodyTarget id ->
                    id

                BoundaryTarget ->
                    -1

        matA =
            Dict.get event.a bodies
                |> Maybe.map .materialName
                |> Maybe.withDefault "Rubber"

        matB =
            case event.b of
                BodyTarget id ->
                    Dict.get id bodies
                        |> Maybe.map .materialName
                        |> Maybe.withDefault "Rubber"

                BoundaryTarget ->
                    "Stone"
    in
    Ports.sendAudioEvent
        { eventType = "collision"
        , energy = event.energy
        , x = event.position.x
        , y = event.position.y
        , a = event.a
        , b = bId
        , step = event.timeStep
        , materialA = matA
        , materialB = matB
        }



-- MIXER PORT HELPER


sendMixerState : Mixer.MixerState -> Cmd Msg
sendMixerState mixer =
    Ports.sendMixerCommand
        { command = "update"
        , volume = mixer.masterVolume
        , muted = mixer.masterMuted
        , reverbEnabled = mixer.reverbEnabled
        , reverbDecay = mixer.reverbDecay
        , reverbMix = mixer.reverbMix
        , delayEnabled = mixer.delayEnabled
        , delayTime = mixer.delayTime
        , delayFeedback = mixer.delayFeedback
        , delayMix = mixer.delayMix
        }



-- WORLD CONSTANT CHANGES


applyWorldChange : WorldChange -> Model -> Model
applyWorldChange change model =
    let
        c =
            model.constraints
    in
    case change of
        AdjGravityX d ->
            { model | constraints = { c | gravity = { x = clamp -1000 1000 (c.gravity.x + d), y = c.gravity.y } } }

        AdjGravityY d ->
            { model | constraints = { c | gravity = { x = c.gravity.x, y = clamp -1000 1000 (c.gravity.y + d) } } }

        AdjDamping d ->
            { model | constraints = { c | damping = clamp 0.9 1.0 (c.damping + d) } }

        AdjEnergyDecay d ->
            { model | constraints = { c | energyDecay = clamp 0.5 1.0 (c.energyDecay + d) } }

        AdjEnergyTransfer d ->
            { model | constraints = { c | energyTransferRate = clamp 0 1.0 (c.energyTransferRate + d) } }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ if model.sim.running then
            Time.every (1000 / toFloat model.constraints.tickRateHz) Tick

          else
            Sub.none
        , Browser.Events.onKeyDown keyDecoder
        , Ports.sceneLoaded SceneLoaded
        , case model.ui.pointer of
            Idle ->
                Sub.none

            _ ->
                Sub.batch
                    [ Browser.Events.onMouseMove
                        (Decode.map2 PointerMove
                            (Decode.field "clientX" Decode.float)
                            (Decode.field "clientY" Decode.float)
                        )
                    , Browser.Events.onMouseUp
                        (Decode.succeed PointerUp)
                    ]
        ]


keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.map3 KeyDown
        (Decode.field "key" Decode.string)
        (Decode.oneOf
            [ Decode.field "ctrlKey" Decode.bool
            , Decode.succeed False
            ]
        )
        (Decode.oneOf
            [ Decode.field "shiftKey" Decode.bool
            , Decode.succeed False
            ]
        )
