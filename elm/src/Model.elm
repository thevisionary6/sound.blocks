module Model exposing (..)

import Dict exposing (Dict)
import History exposing (History)
import Material
import Mixer exposing (MixerState)


-- SNAPSHOT (for undo/redo)


type alias Snapshot =
    { bodies : Dict BodyId Body
    , nextId : BodyId
    , links : Dict LinkId Link
    , nextLinkId : LinkId
    }


-- VECTOR MATH


type alias Vec2 =
    { x : Float
    , y : Float
    }


vecAdd : Vec2 -> Vec2 -> Vec2
vecAdd a b =
    { x = a.x + b.x, y = a.y + b.y }


vecSub : Vec2 -> Vec2 -> Vec2
vecSub a b =
    { x = a.x - b.x, y = a.y - b.y }


vecScale : Float -> Vec2 -> Vec2
vecScale s v =
    { x = v.x * s, y = v.y * s }


vecLen : Vec2 -> Float
vecLen v =
    sqrt (v.x * v.x + v.y * v.y)


vecDot : Vec2 -> Vec2 -> Float
vecDot a b =
    a.x * b.x + a.y * b.y


vecNorm : Vec2 -> Vec2
vecNorm v =
    let
        l =
            vecLen v
    in
    if l < 0.0001 then
        { x = 0, y = 0 }

    else
        { x = v.x / l, y = v.y / l }


vecZero : Vec2
vecZero =
    { x = 0, y = 0 }



-- BODY ID


type alias BodyId =
    Int



-- SHAPES


type Shape
    = Circle { r : Float }
    | Rect { w : Float, h : Float }
    | Pipe { length : Float, diameter : Float, openEnds : ( Bool, Bool ), holes : List Float }
    | Poly { points : List Vec2, boundingR : Float }



-- BODY


type alias A11yInfo =
    { name : String
    , description : String
    }


type alias Body =
    { id : BodyId
    , shape : Shape
    , pos : Vec2
    , vel : Vec2
    , rot : Float
    , angVel : Float
    , mass : Float
    , restitution : Float
    , friction : Float
    , energy : Float
    , tags : List String
    , a11y : A11yInfo
    , materialName : String
    }



-- CAMERA


type alias Camera =
    { offset : Vec2
    , zoom : Float
    }



-- LINKS (physical constraints between bodies)


type alias LinkId =
    Int


type LinkKind
    = StringLink { length : Float }
    | SpringLink { restLength : Float, stiffness : Float }
    | RopeLink { maxLength : Float }
    | WeldLink { relativeOffset : Vec2 }


type alias Link =
    { id : LinkId
    , kind : LinkKind
    , bodyA : BodyId
    , bodyB : BodyId
    }


type LinkCreation
    = NotCreating
    | PickingFirst LinkKind
    | PickingSecond LinkKind BodyId



-- SIM CONSTRAINTS


type BoundaryMode
    = Bounce
    | Wrap
    | Clamp


type CollisionMode
    = NoCollisions
    | SimpleCollisions
    | EnergeticCollisions


type alias Constraints =
    { tickRateHz : Int
    , gravity : Vec2
    , damping : Float
    , boundaryMode : BoundaryMode
    , collisionMode : CollisionMode
    , energyDecay : Float
    , energyTransferRate : Float
    }



-- SIM STATE


type alias SimState =
    { running : Bool
    , fixedDt : Float
    , stepCount : Int
    }



-- UI STATE


type UiMode
    = DrawMode
    | SelectMode
    | RunMode
    | InspectMode
    | BreathMode
    | DrillMode


type DrawTool
    = CircleTool
    | RectTool
    | PipeTool
    | TriangleTool
    | PentagonTool
    | HexagonTool
    | ParallelogramTool
    | TrapezoidTool


type alias Cursor =
    { pos : Vec2
    , visible : Bool
    }


type Panel
    = NoPanel
    | MaterialPanel
    | PropertiesPanel
    | ConstraintPanel
    | MixerPanel
    | WorldPanel


type PointerAction
    = Idle
    | DraggingBody BodyId Vec2
    | Panning Vec2


type alias UiState =
    { mode : UiMode
    , selected : Maybe BodyId
    , hovered : Maybe BodyId
    , drawTool : DrawTool
    , cursor : Cursor
    , panel : Panel
    , pointer : PointerAction
    , activeMaterial : String
    , linkCreation : LinkCreation
    , breathTarget : Maybe BodyId
    }



-- EVENTS


type CollisionTarget
    = BodyTarget BodyId
    | BoundaryTarget


type alias CollisionEvent =
    { a : BodyId
    , b : CollisionTarget
    , position : Vec2
    , normal : Vec2
    , impulse : Float
    , energy : Float
    , timeStep : Int
    }


type alias EventLog =
    { announcements : List String
    , lastCollision : Maybe CollisionEvent
    }



-- BOUNDS


type alias Bounds =
    { width : Float
    , height : Float
    }



-- MODEL


type alias Model =
    { bodies : Dict BodyId Body
    , nextId : BodyId
    , links : Dict LinkId Link
    , nextLinkId : LinkId
    , bounds : Bounds
    , constraints : Constraints
    , sim : SimState
    , ui : UiState
    , log : EventLog
    , camera : Camera
    , history : History Snapshot
    , mixer : MixerState
    }



-- CONSTRUCTORS


makeCircle : BodyId -> Vec2 -> Float -> String -> Body
makeCircle id pos r matName =
    let
        mat =
            Material.getMaterial matName
    in
    { id = id
    , shape = Circle { r = r }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = mat.density * pi * r * r * 0.001
    , restitution = mat.restitution
    , friction = mat.friction
    , energy = 0
    , tags = []
    , a11y =
        { name = "Circle " ++ String.fromInt id
        , description = mat.name ++ " circle, radius " ++ String.fromInt (round r)
        }
    , materialName = matName
    }


makeRect : BodyId -> Vec2 -> Float -> Float -> String -> Body
makeRect id pos w h matName =
    let
        mat =
            Material.getMaterial matName
    in
    { id = id
    , shape = Rect { w = w, h = h }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = mat.density * w * h * 0.0001
    , restitution = mat.restitution
    , friction = mat.friction
    , energy = 0
    , tags = []
    , a11y =
        { name = "Rect " ++ String.fromInt id
        , description = mat.name ++ " rectangle " ++ String.fromInt (round w) ++ "x" ++ String.fromInt (round h)
        }
    , materialName = matName
    }


makePipe : BodyId -> Vec2 -> Float -> Float -> String -> Body
makePipe id pos len diam matName =
    let
        mat =
            Material.getMaterial matName
    in
    { id = id
    , shape = Pipe { length = len, diameter = diam, openEnds = ( True, True ), holes = [] }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = mat.density * len * diam * 0.0001
    , restitution = mat.restitution
    , friction = mat.friction
    , energy = 0
    , tags = [ "pipe" ]
    , a11y =
        { name = "Pipe " ++ String.fromInt id
        , description = mat.name ++ " pipe " ++ String.fromInt (round len) ++ "x" ++ String.fromInt (round diam)
        }
    , materialName = matName
    }


makePoly : BodyId -> Vec2 -> List Vec2 -> String -> String -> Body
makePoly id pos points shapeName matName =
    let
        mat =
            Material.getMaterial matName

        br =
            List.foldl (\p mx -> max mx (vecLen p)) 0 points

        area =
            abs (polyArea points)
    in
    { id = id
    , shape = Poly { points = points, boundingR = br }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = mat.density * area * 0.001
    , restitution = mat.restitution
    , friction = mat.friction
    , energy = 0
    , tags = []
    , a11y =
        { name = shapeName ++ " " ++ String.fromInt id
        , description = mat.name ++ " " ++ shapeName
        }
    , materialName = matName
    }


polyArea : List Vec2 -> Float
polyArea pts =
    case pts of
        [] ->
            0

        first :: _ ->
            let
                shifted =
                    List.drop 1 pts ++ [ first ]

                pairs =
                    List.map2 Tuple.pair pts shifted
            in
            List.foldl (\( a, b ) acc -> acc + (a.x * b.y - b.x * a.y)) 0 pairs / 2


regularPolygon : Int -> Float -> List Vec2
regularPolygon sides radius =
    List.map
        (\i ->
            let
                angle =
                    toFloat i * 2 * pi / toFloat sides - pi / 2
            in
            { x = radius * cos angle
            , y = radius * sin angle
            }
        )
        (List.range 0 (sides - 1))


trianglePoints : Float -> List Vec2
trianglePoints r =
    regularPolygon 3 r


pentagonPoints : Float -> List Vec2
pentagonPoints r =
    regularPolygon 5 r


hexagonPoints : Float -> List Vec2
hexagonPoints r =
    regularPolygon 6 r


parallelogramPoints : Float -> Float -> List Vec2
parallelogramPoints w h =
    let
        skew =
            w * 0.25
    in
    [ { x = -w / 2 + skew, y = -h / 2 }
    , { x = w / 2 + skew, y = -h / 2 }
    , { x = w / 2 - skew, y = h / 2 }
    , { x = -w / 2 - skew, y = h / 2 }
    ]


trapezoidPoints : Float -> Float -> List Vec2
trapezoidPoints w h =
    [ { x = -w * 0.3, y = -h / 2 }
    , { x = w * 0.3, y = -h / 2 }
    , { x = w / 2, y = h / 2 }
    , { x = -w / 2, y = h / 2 }
    ]


bodyRadius : Body -> Float
bodyRadius body =
    case body.shape of
        Circle { r } ->
            r

        Rect { w, h } ->
            sqrt (w * w + h * h) / 2

        Pipe { length, diameter } ->
            sqrt (length * length + diameter * diameter) / 2

        Poly { boundingR } ->
            boundingR


bodyLabel : Body -> String
bodyLabel body =
    body.a11y.name



-- INITIAL MODEL


initialModel : Model
initialModel =
    { bodies = Dict.empty
    , nextId = 1
    , links = Dict.empty
    , nextLinkId = 1
    , bounds = { width = 800, height = 600 }
    , constraints =
        { tickRateHz = 30
        , gravity = { x = 0, y = 300 }
        , damping = 0.999
        , boundaryMode = Bounce
        , collisionMode = EnergeticCollisions
        , energyDecay = 0.95
        , energyTransferRate = 0.1
        }
    , sim =
        { running = True
        , fixedDt = 1.0 / 30.0
        , stepCount = 0
        }
    , ui =
        { mode = DrawMode
        , selected = Nothing
        , hovered = Nothing
        , drawTool = CircleTool
        , cursor =
            { pos = { x = 400, y = 300 }
            , visible = True
            }
        , panel = NoPanel
        , pointer = Idle
        , activeMaterial = "Rubber"
        , linkCreation = NotCreating
        , breathTarget = Nothing
        }
    , log =
        { announcements =
            [ "Sound Blocks ready. Draw mode. Arrows move cursor, Enter places shape, Tab to Select mode." ]
        , lastCollision = Nothing
        }
    , camera =
        { offset = vecZero
        , zoom = 1.0
        }
    , history = History.empty
    , mixer = Mixer.defaultMixer
    }


currentAnnouncement : Model -> String
currentAnnouncement model =
    case model.log.announcements of
        first :: _ ->
            first

        [] ->
            ""


announce : String -> Model -> Model
announce msg model =
    let
        log =
            model.log

        newAnnouncements =
            msg :: List.take 19 log.announcements
    in
    { model | log = { log | announcements = newAnnouncements } }


screenToWorld : Camera -> Vec2 -> Vec2
screenToWorld camera screenPos =
    { x = screenPos.x / camera.zoom + camera.offset.x
    , y = screenPos.y / camera.zoom + camera.offset.y
    }
