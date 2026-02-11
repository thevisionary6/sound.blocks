module Update exposing (Msg(..), subscriptions, update)

import Browser.Events
import Dict
import Json.Decode as Decode
import Model exposing (..)
import Physics.Step
import Ports
import Time


type Msg
    = Tick Time.Posix
    | KeyDown String
    | ToggleRun
    | ToggleMode
    | Clear
    | ClickBody BodyId
    | SetDrawTool DrawTool
    | SetBoundaryMode BoundaryMode
    | SetCollisionMode CollisionMode


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick _ ->
            if model.sim.running then
                let
                    sim =
                        model.sim

                    result =
                        Physics.Step.step model.constraints model.bounds sim.stepCount model.bodies

                    cmds =
                        List.map collisionToAudioCmd result.events
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
                            DrawMode
            in
            ( announce (modeAnnouncement newMode)
                { model | ui = { ui | mode = newMode } }
            , Cmd.none
            )

        Clear ->
            ( announce "All bodies cleared."
                { model
                    | bodies = Dict.empty
                    , nextId = 1
                    , ui = setSelected Nothing model.ui
                }
            , Cmd.none
            )

        ClickBody id ->
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

        KeyDown key ->
            handleKey key model


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


handleKey : String -> Model -> ( Model, Cmd Msg )
handleKey key model =
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
            placeShape model

        " " ->
            placeShape model

        "Tab" ->
            announce "Select mode. Tab through bodies, arrow keys nudge selected body."
                { model | ui = { ui | mode = SelectMode } }

        "Escape" ->
            model

        _ ->
            model


placeShape : Model -> Model
placeShape model =
    let
        ui =
            model.ui

        pos =
            ui.cursor.pos

        ( newBody, shapeLabel ) =
            case ui.drawTool of
                CircleTool ->
                    ( makeCircle model.nextId pos 20, "Circle" )

                RectTool ->
                    ( makeRect model.nextId pos 40 30, "Rect" )

        newBodies =
            Dict.insert model.nextId newBody model.bodies
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
        { model
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

                        newBodies =
                            Dict.remove id model.bodies
                    in
                    announce
                        (name ++ " deleted. " ++ String.fromInt (Dict.size newBodies) ++ " bodies remaining.")
                        { model
                            | bodies = newBodies
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


collisionToAudioCmd : CollisionEvent -> Cmd Msg
collisionToAudioCmd event =
    let
        bId =
            case event.b of
                BodyTarget id ->
                    id

                BoundaryTarget ->
                    -1
    in
    Ports.sendAudioEvent
        { eventType = "collision"
        , energy = event.energy
        , x = event.position.x
        , y = event.position.y
        , a = event.a
        , b = bId
        , step = event.timeStep
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ if model.sim.running then
            Time.every (1000 / toFloat model.constraints.tickRateHz) Tick

          else
            Sub.none
        , Browser.Events.onKeyDown
            (Decode.field "key" Decode.string
                |> Decode.map KeyDown
            )
        ]
