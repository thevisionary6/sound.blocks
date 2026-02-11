module Model exposing (..)

import Dict exposing (Dict)


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
    }



-- CONSTRAINTS


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


type DrawTool
    = CircleTool
    | RectTool


type alias Cursor =
    { pos : Vec2
    , visible : Bool
    }


type alias UiState =
    { mode : UiMode
    , selected : Maybe BodyId
    , hovered : Maybe BodyId
    , drawTool : DrawTool
    , cursor : Cursor
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
    , bounds : Bounds
    , constraints : Constraints
    , sim : SimState
    , ui : UiState
    , log : EventLog
    }



-- CONSTRUCTORS


makeCircle : BodyId -> Vec2 -> Float -> Body
makeCircle id pos r =
    { id = id
    , shape = Circle { r = r }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = r * r * 0.01
    , restitution = 0.7
    , friction = 0.3
    , energy = 0
    , tags = []
    , a11y =
        { name = "Circle " ++ String.fromInt id
        , description = "Circle with radius " ++ String.fromInt (round r)
        }
    }


makeRect : BodyId -> Vec2 -> Float -> Float -> Body
makeRect id pos w h =
    { id = id
    , shape = Rect { w = w, h = h }
    , pos = pos
    , vel = vecZero
    , rot = 0
    , angVel = 0
    , mass = w * h * 0.0001
    , restitution = 0.6
    , friction = 0.4
    , energy = 0
    , tags = []
    , a11y =
        { name = "Rect " ++ String.fromInt id
        , description = "Rectangle " ++ String.fromInt (round w) ++ "x" ++ String.fromInt (round h)
        }
    }


bodyRadius : Body -> Float
bodyRadius body =
    case body.shape of
        Circle { r } ->
            r

        Rect { w, h } ->
            sqrt (w * w + h * h) / 2


bodyLabel : Body -> String
bodyLabel body =
    body.a11y.name



-- INITIAL MODEL


initialModel : Model
initialModel =
    { bodies = Dict.empty
    , nextId = 1
    , bounds = { width = 800, height = 600 }
    , constraints =
        { tickRateHz = 30
        , gravity = { x = 0, y = 300 }
        , damping = 0.999
        , boundaryMode = Bounce
        , collisionMode = EnergeticCollisions
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
            { pos = { x = 400, y = 200 }
            , visible = True
            }
        }
    , log =
        { announcements =
            [ "Particle Forge ready. Draw mode. Arrow keys move cursor, Enter places a shape, Tab to switch to Select mode." ]
        , lastCollision = Nothing
        }
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
