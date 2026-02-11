module Serialization exposing (encodeScene, decodeScene)

import Dict exposing (Dict)
import Json.Decode as D
import Json.Encode as E
import Mixer exposing (MixerState)
import Model exposing (..)


type alias Scene =
    { bodies : Dict BodyId Body
    , nextId : BodyId
    , links : Dict LinkId Link
    , nextLinkId : LinkId
    , constraints : Constraints
    , mixer : MixerState
    , camera : Camera
    , bounds : Bounds
    }



-- ENCODE


encodeScene : Model -> E.Value
encodeScene model =
    E.object
        [ ( "version", E.int 1 )
        , ( "bodies", E.list encodeBody (Dict.values model.bodies) )
        , ( "nextId", E.int model.nextId )
        , ( "links", E.list encodeLink (Dict.values model.links) )
        , ( "nextLinkId", E.int model.nextLinkId )
        , ( "constraints", encodeConstraints model.constraints )
        , ( "mixer", encodeMixer model.mixer )
        , ( "camera", encodeCamera model.camera )
        , ( "bounds", encodeBounds model.bounds )
        ]


encodeVec2 : Vec2 -> E.Value
encodeVec2 v =
    E.object [ ( "x", E.float v.x ), ( "y", E.float v.y ) ]


encodeShape : Shape -> E.Value
encodeShape shape =
    case shape of
        Circle { r } ->
            E.object [ ( "type", E.string "circle" ), ( "r", E.float r ) ]

        Rect { w, h } ->
            E.object [ ( "type", E.string "rect" ), ( "w", E.float w ), ( "h", E.float h ) ]

        Pipe { length, diameter, openEnds, holes } ->
            let
                ( leftOpen, rightOpen ) =
                    openEnds
            in
            E.object
                [ ( "type", E.string "pipe" )
                , ( "length", E.float length )
                , ( "diameter", E.float diameter )
                , ( "leftOpen", E.bool leftOpen )
                , ( "rightOpen", E.bool rightOpen )
                , ( "holes", E.list E.float holes )
                ]

        Poly { points, boundingR } ->
            E.object
                [ ( "type", E.string "poly" )
                , ( "points", E.list encodeVec2 points )
                , ( "boundingR", E.float boundingR )
                ]


encodeBody : Body -> E.Value
encodeBody body =
    E.object
        [ ( "id", E.int body.id )
        , ( "shape", encodeShape body.shape )
        , ( "pos", encodeVec2 body.pos )
        , ( "vel", encodeVec2 body.vel )
        , ( "rot", E.float body.rot )
        , ( "angVel", E.float body.angVel )
        , ( "mass", E.float body.mass )
        , ( "restitution", E.float body.restitution )
        , ( "friction", E.float body.friction )
        , ( "energy", E.float body.energy )
        , ( "tags", E.list E.string body.tags )
        , ( "a11yName", E.string body.a11y.name )
        , ( "a11yDesc", E.string body.a11y.description )
        , ( "materialName", E.string body.materialName )
        ]


encodeLinkKind : LinkKind -> E.Value
encodeLinkKind kind =
    case kind of
        StringLink { length } ->
            E.object [ ( "type", E.string "string" ), ( "length", E.float length ) ]

        SpringLink { restLength, stiffness } ->
            E.object
                [ ( "type", E.string "spring" )
                , ( "restLength", E.float restLength )
                , ( "stiffness", E.float stiffness )
                ]

        RopeLink { maxLength } ->
            E.object [ ( "type", E.string "rope" ), ( "maxLength", E.float maxLength ) ]

        WeldLink { relativeOffset } ->
            E.object [ ( "type", E.string "weld" ), ( "offset", encodeVec2 relativeOffset ) ]


encodeLink : Link -> E.Value
encodeLink link =
    E.object
        [ ( "id", E.int link.id )
        , ( "kind", encodeLinkKind link.kind )
        , ( "bodyA", E.int link.bodyA )
        , ( "bodyB", E.int link.bodyB )
        ]


encodeConstraints : Constraints -> E.Value
encodeConstraints c =
    E.object
        [ ( "tickRateHz", E.int c.tickRateHz )
        , ( "gravity", encodeVec2 c.gravity )
        , ( "damping", E.float c.damping )
        , ( "boundaryMode", E.string (boundaryModeStr c.boundaryMode) )
        , ( "collisionMode", E.string (collisionModeStr c.collisionMode) )
        , ( "energyDecay", E.float c.energyDecay )
        , ( "energyTransferRate", E.float c.energyTransferRate )
        ]


boundaryModeStr : BoundaryMode -> String
boundaryModeStr mode =
    case mode of
        Bounce ->
            "bounce"

        Wrap ->
            "wrap"

        Clamp ->
            "clamp"


collisionModeStr : CollisionMode -> String
collisionModeStr mode =
    case mode of
        NoCollisions ->
            "none"

        SimpleCollisions ->
            "simple"

        EnergeticCollisions ->
            "energetic"


encodeMixer : MixerState -> E.Value
encodeMixer m =
    E.object
        [ ( "masterVolume", E.float m.masterVolume )
        , ( "masterMuted", E.bool m.masterMuted )
        , ( "reverbEnabled", E.bool m.reverbEnabled )
        , ( "reverbDecay", E.float m.reverbDecay )
        , ( "reverbMix", E.float m.reverbMix )
        , ( "delayEnabled", E.bool m.delayEnabled )
        , ( "delayTime", E.float m.delayTime )
        , ( "delayFeedback", E.float m.delayFeedback )
        , ( "delayMix", E.float m.delayMix )
        ]


encodeCamera : Camera -> E.Value
encodeCamera cam =
    E.object
        [ ( "offset", encodeVec2 cam.offset )
        , ( "zoom", E.float cam.zoom )
        ]


encodeBounds : Bounds -> E.Value
encodeBounds b =
    E.object
        [ ( "width", E.float b.width )
        , ( "height", E.float b.height )
        ]



-- DECODE


decodeScene : D.Decoder Scene
decodeScene =
    D.map8 Scene
        (D.field "bodies" (D.list decodeBody |> D.map bodyListToDict))
        (D.field "nextId" D.int)
        (D.field "links" (D.list decodeLink |> D.map linkListToDict))
        (D.field "nextLinkId" D.int)
        (D.field "constraints" decodeConstraints)
        (D.field "mixer" decodeMixer)
        (D.field "camera" decodeCamera)
        (D.field "bounds" decodeBounds)


bodyListToDict : List Body -> Dict BodyId Body
bodyListToDict bodies =
    List.foldl (\b d -> Dict.insert b.id b d) Dict.empty bodies


linkListToDict : List Link -> Dict LinkId Link
linkListToDict links =
    List.foldl (\l d -> Dict.insert l.id l d) Dict.empty links


decodeVec2 : D.Decoder Vec2
decodeVec2 =
    D.map2 Vec2
        (D.field "x" D.float)
        (D.field "y" D.float)


decodeShape : D.Decoder Shape
decodeShape =
    D.field "type" D.string
        |> D.andThen
            (\t ->
                case t of
                    "circle" ->
                        D.map (\r -> Circle { r = r }) (D.field "r" D.float)

                    "rect" ->
                        D.map2 (\w h -> Rect { w = w, h = h })
                            (D.field "w" D.float)
                            (D.field "h" D.float)

                    "pipe" ->
                        D.map4
                            (\len diam ends holes ->
                                Pipe { length = len, diameter = diam, openEnds = ends, holes = holes }
                            )
                            (D.field "length" D.float)
                            (D.field "diameter" D.float)
                            (D.map2 Tuple.pair (D.field "leftOpen" D.bool) (D.field "rightOpen" D.bool))
                            (D.field "holes" (D.list D.float))

                    "poly" ->
                        D.map2 (\pts br -> Poly { points = pts, boundingR = br })
                            (D.field "points" (D.list decodeVec2))
                            (D.field "boundingR" D.float)

                    _ ->
                        D.fail ("Unknown shape type: " ++ t)
            )


decodeBody : D.Decoder Body
decodeBody =
    let
        decodeA11y =
            D.map2 A11yInfo
                (D.field "a11yName" D.string)
                (D.field "a11yDesc" D.string)
    in
    D.succeed Body
        |> andMap (D.field "id" D.int)
        |> andMap (D.field "shape" decodeShape)
        |> andMap (D.field "pos" decodeVec2)
        |> andMap (D.field "vel" decodeVec2)
        |> andMap (D.field "rot" D.float)
        |> andMap (D.field "angVel" D.float)
        |> andMap (D.field "mass" D.float)
        |> andMap (D.field "restitution" D.float)
        |> andMap (D.field "friction" D.float)
        |> andMap (D.field "energy" D.float)
        |> andMap (D.field "tags" (D.list D.string))
        |> andMap decodeA11y
        |> andMap (D.field "materialName" D.string)


andMap : D.Decoder a -> D.Decoder (a -> b) -> D.Decoder b
andMap =
    D.map2 (|>)


decodeLinkKind : D.Decoder LinkKind
decodeLinkKind =
    D.field "type" D.string
        |> D.andThen
            (\t ->
                case t of
                    "string" ->
                        D.map (\l -> StringLink { length = l }) (D.field "length" D.float)

                    "spring" ->
                        D.map2 (\rl s -> SpringLink { restLength = rl, stiffness = s })
                            (D.field "restLength" D.float)
                            (D.field "stiffness" D.float)

                    "rope" ->
                        D.map (\ml -> RopeLink { maxLength = ml }) (D.field "maxLength" D.float)

                    "weld" ->
                        D.map (\o -> WeldLink { relativeOffset = o }) (D.field "offset" decodeVec2)

                    _ ->
                        D.fail ("Unknown link type: " ++ t)
            )


decodeLink : D.Decoder Link
decodeLink =
    D.map4 Link
        (D.field "id" D.int)
        (D.field "kind" decodeLinkKind)
        (D.field "bodyA" D.int)
        (D.field "bodyB" D.int)


decodeConstraints : D.Decoder Constraints
decodeConstraints =
    D.succeed Constraints
        |> andMap (D.field "tickRateHz" D.int)
        |> andMap (D.field "gravity" decodeVec2)
        |> andMap (D.field "damping" D.float)
        |> andMap (D.field "boundaryMode" decodeBoundaryMode)
        |> andMap (D.field "collisionMode" decodeCollisionMode)
        |> andMap (fieldWithDefault "energyDecay" D.float 0.95)
        |> andMap (fieldWithDefault "energyTransferRate" D.float 0.1)


fieldWithDefault : String -> D.Decoder a -> a -> D.Decoder a
fieldWithDefault name decoder default =
    D.oneOf [ D.field name decoder, D.succeed default ]


decodeBoundaryMode : D.Decoder BoundaryMode
decodeBoundaryMode =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "bounce" ->
                        D.succeed Bounce

                    "wrap" ->
                        D.succeed Wrap

                    "clamp" ->
                        D.succeed Clamp

                    _ ->
                        D.succeed Bounce
            )


decodeCollisionMode : D.Decoder CollisionMode
decodeCollisionMode =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "none" ->
                        D.succeed NoCollisions

                    "simple" ->
                        D.succeed SimpleCollisions

                    "energetic" ->
                        D.succeed EnergeticCollisions

                    _ ->
                        D.succeed EnergeticCollisions
            )


decodeMixer : D.Decoder MixerState
decodeMixer =
    D.succeed MixerState
        |> andMap (D.field "masterVolume" D.float)
        |> andMap (D.field "masterMuted" D.bool)
        |> andMap (D.field "reverbEnabled" D.bool)
        |> andMap (D.field "reverbDecay" D.float)
        |> andMap (D.field "reverbMix" D.float)
        |> andMap (D.field "delayEnabled" D.bool)
        |> andMap (D.field "delayTime" D.float)
        |> andMap (D.field "delayFeedback" D.float)
        |> andMap (D.field "delayMix" D.float)


decodeCamera : D.Decoder Camera
decodeCamera =
    D.map2 Camera
        (D.field "offset" decodeVec2)
        (D.field "zoom" D.float)


decodeBounds : D.Decoder Bounds
decodeBounds =
    D.map2 Bounds
        (D.field "width" D.float)
        (D.field "height" D.float)
