module View.Svg exposing (Msg(..), viewWorld)

import Dict
import Html exposing (Html)
import Html.Attributes
import Json.Decode as Decode
import Material
import Model exposing (..)
import Svg exposing (..)
import Svg.Attributes as SA
import Svg.Events as SE


type Msg
    = ClickBody BodyId
    | PointerDownOnBody BodyId Float Float
    | PointerDownOnBg Float Float Float Float
    | NoOp


viewWorld : Model -> (Msg -> msg) -> Html msg
viewWorld model toMsg =
    let
        cam =
            model.camera

        vw =
            model.bounds.width / cam.zoom

        vh =
            model.bounds.height / cam.zoom

        viewBoxStr =
            String.fromFloat cam.offset.x
                ++ " "
                ++ String.fromFloat cam.offset.y
                ++ " "
                ++ String.fromFloat vw
                ++ " "
                ++ String.fromFloat vh

        w =
            String.fromFloat model.bounds.width

        h =
            String.fromFloat model.bounds.height
    in
    svg
        [ SA.width w
        , SA.height h
        , SA.viewBox viewBoxStr
        , SA.style "background: #0a0a0f; display: block;"
        , Html.Attributes.attribute "role" "application"
        , Html.Attributes.attribute "aria-label"
            ("Simulation viewport, "
                ++ String.fromInt (Dict.size model.bodies)
                ++ " bodies. "
                ++ modeLabel model.ui.mode
            )
        , onPointerDown (\ox oy cx cy -> toMsg (PointerDownOnBg ox oy cx cy))
        ]
        ([ viewFloor model.bounds
         , viewBoundsRect model.bounds
         ]
            ++ List.map (viewLink model.bodies) (Dict.values model.links)
            ++ List.map (viewBody model.ui.selected toMsg) (Dict.values model.bodies)
            ++ viewCursor model
        )


onPointerDown : (Float -> Float -> Float -> Float -> msg) -> Svg.Attribute msg
onPointerDown toMsg =
    SE.on "mousedown"
        (Decode.map4 toMsg
            (Decode.field "offsetX" Decode.float)
            (Decode.field "offsetY" Decode.float)
            (Decode.field "clientX" Decode.float)
            (Decode.field "clientY" Decode.float)
        )


onBodyPointerDown : (Float -> Float -> msg) -> Svg.Attribute msg
onBodyPointerDown toMsg =
    SE.stopPropagationOn "mousedown"
        (Decode.map2 (\x y -> ( toMsg x y, True ))
            (Decode.field "clientX" Decode.float)
            (Decode.field "clientY" Decode.float)
        )


modeLabel : UiMode -> String
modeLabel mode =
    case mode of
        DrawMode ->
            "Draw mode"

        SelectMode ->
            "Select mode"

        RunMode ->
            "Run mode"

        InspectMode ->
            "Inspect mode"


viewFloor : Bounds -> Svg msg
viewFloor bounds =
    rect
        [ SA.x "0"
        , SA.y (String.fromFloat (bounds.height - 4))
        , SA.width (String.fromFloat bounds.width)
        , SA.height "4"
        , SA.fill "#3a3a4a"
        ]
        []


viewBoundsRect : Bounds -> Svg msg
viewBoundsRect bounds =
    rect
        [ SA.x "0"
        , SA.y "0"
        , SA.width (String.fromFloat bounds.width)
        , SA.height (String.fromFloat bounds.height)
        , SA.fill "none"
        , SA.stroke "#2a2a3a"
        , SA.strokeWidth "2"
        ]
        []


viewBody : Maybe BodyId -> (Msg -> msg) -> Body -> Svg msg
viewBody selected toMsg body =
    let
        isSelected =
            selected == Just body.id

        energyGlow =
            if body.energy > 1 then
                min 1.0 (body.energy / 20)

            else
                0
    in
    g []
        (selectionRing isSelected body
            ++ energyRing energyGlow body
            ++ [ viewShape isSelected toMsg body ]
        )


selectionRing : Bool -> Body -> List (Svg msg)
selectionRing isSelected body =
    if isSelected then
        case body.shape of
            Circle { r } ->
                [ circle
                    [ SA.cx (String.fromFloat body.pos.x)
                    , SA.cy (String.fromFloat body.pos.y)
                    , SA.r (String.fromFloat (r + 4))
                    , SA.fill "none"
                    , SA.stroke "#ff6b3d"
                    , SA.strokeWidth "2"
                    , SA.strokeDasharray "4 3"
                    , SA.opacity "0.7"
                    ]
                    []
                ]

            Rect { w, h } ->
                [ rect
                    [ SA.x (String.fromFloat (body.pos.x - w / 2 - 4))
                    , SA.y (String.fromFloat (body.pos.y - h / 2 - 4))
                    , SA.width (String.fromFloat (w + 8))
                    , SA.height (String.fromFloat (h + 8))
                    , SA.fill "none"
                    , SA.stroke "#ff6b3d"
                    , SA.strokeWidth "2"
                    , SA.strokeDasharray "4 3"
                    , SA.opacity "0.7"
                    , SA.transform (rotateTransform body)
                    ]
                    []
                ]

    else
        []


energyRing : Float -> Body -> List (Svg msg)
energyRing glow body =
    if glow > 0.05 then
        case body.shape of
            Circle { r } ->
                [ circle
                    [ SA.cx (String.fromFloat body.pos.x)
                    , SA.cy (String.fromFloat body.pos.y)
                    , SA.r (String.fromFloat (r + 2 + glow * 8))
                    , SA.fill "none"
                    , SA.stroke "#ffaa33"
                    , SA.strokeWidth "1.5"
                    , SA.opacity (String.fromFloat (glow * 0.6))
                    ]
                    []
                ]

            Rect { w, h } ->
                let
                    offset =
                        2 + glow * 8
                in
                [ rect
                    [ SA.x (String.fromFloat (body.pos.x - w / 2 - offset))
                    , SA.y (String.fromFloat (body.pos.y - h / 2 - offset))
                    , SA.width (String.fromFloat (w + offset * 2))
                    , SA.height (String.fromFloat (h + offset * 2))
                    , SA.fill "none"
                    , SA.stroke "#ffaa33"
                    , SA.strokeWidth "1.5"
                    , SA.opacity (String.fromFloat (glow * 0.6))
                    , SA.rx "3"
                    , SA.transform (rotateTransform body)
                    ]
                    []
                ]

    else
        []


viewShape : Bool -> (Msg -> msg) -> Body -> Svg msg
viewShape isSelected toMsg body =
    let
        label =
            bodyLabel body

        mat =
            Material.getMaterial body.materialName

        ariaLabel =
            label
                ++ " ("
                ++ mat.name
                ++ ") at "
                ++ String.fromInt (round body.pos.x)
                ++ ", "
                ++ String.fromInt (round body.pos.y)
                ++ (if isSelected then
                        ", selected"

                    else
                        ""
                   )

        commonAttrs =
            [ Html.Attributes.attribute "tabindex" "0"
            , Html.Attributes.attribute "role" "button"
            , Html.Attributes.attribute "aria-label" ariaLabel
            , onBodyPointerDown (\x y -> toMsg (PointerDownOnBody body.id x y))
            , SE.onClick (toMsg (ClickBody body.id))
            ]
    in
    case body.shape of
        Circle { r } ->
            circle
                ([ SA.cx (String.fromFloat body.pos.x)
                 , SA.cy (String.fromFloat body.pos.y)
                 , SA.r (String.fromFloat r)
                 , SA.fill mat.color
                 , SA.opacity
                    (String.fromFloat
                        (if isSelected then
                            mat.alpha

                         else
                            mat.alpha * 0.85
                        )
                    )
                 ]
                    ++ commonAttrs
                )
                [ Svg.title [] [ text label ] ]

        Rect { w, h } ->
            rect
                ([ SA.x (String.fromFloat (body.pos.x - w / 2))
                 , SA.y (String.fromFloat (body.pos.y - h / 2))
                 , SA.width (String.fromFloat w)
                 , SA.height (String.fromFloat h)
                 , SA.fill mat.color
                 , SA.rx "3"
                 , SA.opacity
                    (String.fromFloat
                        (if isSelected then
                            mat.alpha

                         else
                            mat.alpha * 0.85
                        )
                    )
                 , SA.transform (rotateTransform body)
                 ]
                    ++ commonAttrs
                )
                [ Svg.title [] [ text label ] ]


rotateTransform : Body -> String
rotateTransform body =
    if abs body.rot > 0.01 then
        "rotate("
            ++ String.fromFloat (body.rot * 180 / pi)
            ++ " "
            ++ String.fromFloat body.pos.x
            ++ " "
            ++ String.fromFloat body.pos.y
            ++ ")"

    else
        ""


viewCursor : Model -> List (Svg msg)
viewCursor model =
    if model.ui.cursor.visible && model.ui.mode == DrawMode then
        let
            cx =
                String.fromFloat model.ui.cursor.pos.x

            cy =
                String.fromFloat model.ui.cursor.pos.y

            mat =
                Material.getMaterial model.ui.activeMaterial

            previewShape =
                case model.ui.drawTool of
                    CircleTool ->
                        [ circle
                            [ SA.cx cx
                            , SA.cy cy
                            , SA.r "20"
                            , SA.fill "none"
                            , SA.stroke mat.color
                            , SA.strokeWidth "1.5"
                            , SA.opacity "0.4"
                            , SA.strokeDasharray "6 4"
                            ]
                            []
                        ]

                    RectTool ->
                        [ rect
                            [ SA.x (String.fromFloat (model.ui.cursor.pos.x - 20))
                            , SA.y (String.fromFloat (model.ui.cursor.pos.y - 15))
                            , SA.width "40"
                            , SA.height "30"
                            , SA.fill "none"
                            , SA.stroke mat.color
                            , SA.strokeWidth "1.5"
                            , SA.opacity "0.4"
                            , SA.strokeDasharray "6 4"
                            , SA.rx "3"
                            ]
                            []
                        ]
        in
        previewShape
            ++ [ line
                    [ SA.x1 cx
                    , SA.y1 (String.fromFloat (model.ui.cursor.pos.y - 8))
                    , SA.x2 cx
                    , SA.y2 (String.fromFloat (model.ui.cursor.pos.y + 8))
                    , SA.stroke mat.color
                    , SA.strokeWidth "1"
                    , SA.opacity "0.5"
                    ]
                    []
               , line
                    [ SA.x1 (String.fromFloat (model.ui.cursor.pos.x - 8))
                    , SA.y1 cy
                    , SA.x2 (String.fromFloat (model.ui.cursor.pos.x + 8))
                    , SA.y2 cy
                    , SA.stroke mat.color
                    , SA.strokeWidth "1"
                    , SA.opacity "0.5"
                    ]
                    []
               ]

    else
        []



-- LINK RENDERING


viewLink : Dict.Dict BodyId Body -> Link -> Svg msg
viewLink bodies link =
    case ( Dict.get link.bodyA bodies, Dict.get link.bodyB bodies ) of
        ( Just a, Just b ) ->
            case link.kind of
                StringLink _ ->
                    viewStringLink a b

                SpringLink _ ->
                    viewSpringLink a b

                RopeLink _ ->
                    viewRopeLink a b

                WeldLink _ ->
                    viewWeldLink a b

        _ ->
            g [] []


viewStringLink : Body -> Body -> Svg msg
viewStringLink a b =
    line
        [ SA.x1 (String.fromFloat a.pos.x)
        , SA.y1 (String.fromFloat a.pos.y)
        , SA.x2 (String.fromFloat b.pos.x)
        , SA.y2 (String.fromFloat b.pos.y)
        , SA.stroke "#88aa55"
        , SA.strokeWidth "1.5"
        , SA.opacity "0.8"
        ]
        []


viewSpringLink : Body -> Body -> Svg msg
viewSpringLink a b =
    let
        dx =
            b.pos.x - a.pos.x

        dy =
            b.pos.y - a.pos.y

        dist =
            sqrt (dx * dx + dy * dy)

        segments =
            8

        amplitude =
            6

        ux =
            if dist > 0.001 then
                dx / dist

            else
                1

        uy =
            if dist > 0.001 then
                dy / dist

            else
                0

        px =
            -uy

        py =
            ux

        zigzagPoints =
            List.map
                (\i ->
                    let
                        t =
                            toFloat i / toFloat segments

                        baseX =
                            a.pos.x + dx * t

                        baseY =
                            a.pos.y + dy * t

                        sign =
                            if modBy 2 i == 0 then
                                1

                            else
                                -1

                        offset =
                            if i == 0 || i == segments then
                                0

                            else
                                toFloat sign * amplitude
                    in
                    String.fromFloat (baseX + px * offset)
                        ++ ","
                        ++ String.fromFloat (baseY + py * offset)
                )
                (List.range 0 segments)

        pathData =
            "M " ++ String.join " L " zigzagPoints
    in
    Svg.path
        [ SA.d pathData
        , SA.stroke "#55aa88"
        , SA.strokeWidth "1.5"
        , SA.fill "none"
        , SA.opacity "0.8"
        ]
        []


viewRopeLink : Body -> Body -> Svg msg
viewRopeLink a b =
    line
        [ SA.x1 (String.fromFloat a.pos.x)
        , SA.y1 (String.fromFloat a.pos.y)
        , SA.x2 (String.fromFloat b.pos.x)
        , SA.y2 (String.fromFloat b.pos.y)
        , SA.stroke "#aa8855"
        , SA.strokeWidth "1.5"
        , SA.strokeDasharray "6 3"
        , SA.opacity "0.8"
        ]
        []


viewWeldLink : Body -> Body -> Svg msg
viewWeldLink a b =
    line
        [ SA.x1 (String.fromFloat a.pos.x)
        , SA.y1 (String.fromFloat a.pos.y)
        , SA.x2 (String.fromFloat b.pos.x)
        , SA.y2 (String.fromFloat b.pos.y)
        , SA.stroke "#aa5555"
        , SA.strokeWidth "3"
        , SA.opacity "0.7"
        ]
        []
