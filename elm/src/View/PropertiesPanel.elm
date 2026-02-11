module View.PropertiesPanel exposing (PropertyChange(..), viewPropertiesPanel)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Model exposing (..)


type PropertyChange
    = AdjPosX Float
    | AdjPosY Float
    | AdjRadius Float
    | AdjWidth Float
    | AdjHeight Float
    | AdjMass Float
    | AdjFriction Float
    | AdjRestitution Float


viewPropertiesPanel : Body -> (PropertyChange -> msg) -> msg -> Html msg
viewPropertiesPanel body changeMsg closeMsg =
    div
        [ style "position" "absolute"
        , style "top" "60px"
        , style "right" "16px"
        , style "background" "#13131a"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "8px"
        , style "padding" "12px"
        , style "z-index" "100"
        , style "min-width" "220px"
        , style "font-family" "'JetBrains Mono', monospace"
        , style "font-size" "11px"
        , attribute "role" "dialog"
        , attribute "aria-label" "Body properties"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-bottom" "8px"
            ]
            [ span
                [ style "color" "#ff6b3d"
                , style "font-size" "13px"
                , style "font-family" "'Outfit', sans-serif"
                ]
                [ text (bodyLabel body) ]
            , button
                [ onClick closeMsg
                , style "background" "none"
                , style "border" "none"
                , style "color" "#7a7a8e"
                , style "cursor" "pointer"
                , style "font-size" "14px"
                , attribute "aria-label" "Close properties panel"
                ]
                [ text "x" ]
            ]
        , propRow "Pos X" (round body.pos.x) 5 (\d -> changeMsg (AdjPosX d))
        , propRow "Pos Y" (round body.pos.y) 5 (\d -> changeMsg (AdjPosY d))
        , case body.shape of
            Circle { r } ->
                propRow "Radius" (round r) 2 (\d -> changeMsg (AdjRadius d))

            Rect { w, h } ->
                div []
                    [ propRow "Width" (round w) 5 (\d -> changeMsg (AdjWidth d))
                    , propRow "Height" (round h) 5 (\d -> changeMsg (AdjHeight d))
                    ]

            Pipe { length, diameter } ->
                div []
                    [ propRow "Length" (round length) 5 (\d -> changeMsg (AdjWidth d))
                    , propRow "Diameter" (round diameter) 5 (\d -> changeMsg (AdjHeight d))
                    ]
        , propRowFloat "Mass" body.mass 0.5 (\d -> changeMsg (AdjMass d))
        , propRowFloat "Friction" body.friction 0.05 (\d -> changeMsg (AdjFriction d))
        , propRowFloat "Bounce" body.restitution 0.05 (\d -> changeMsg (AdjRestitution d))
        ]


propRow : String -> Int -> Float -> (Float -> msg) -> Html msg
propRow label val step toMsg =
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "margin-bottom" "4px"
        , style "gap" "4px"
        ]
        [ span
            [ style "color" "#7a7a8e"
            , style "min-width" "60px"
            ]
            [ text label ]
        , adjButton "-" (toMsg -step)
        , span
            [ style "color" "#e0e0ec"
            , style "min-width" "40px"
            , style "text-align" "center"
            ]
            [ text (String.fromInt val) ]
        , adjButton "+" (toMsg step)
        ]


propRowFloat : String -> Float -> Float -> (Float -> msg) -> Html msg
propRowFloat label val step toMsg =
    let
        display =
            String.fromFloat (toFloat (round (val * 100)) / 100)
    in
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "margin-bottom" "4px"
        , style "gap" "4px"
        ]
        [ span
            [ style "color" "#7a7a8e"
            , style "min-width" "60px"
            ]
            [ text label ]
        , adjButton "-" (toMsg -step)
        , span
            [ style "color" "#e0e0ec"
            , style "min-width" "40px"
            , style "text-align" "center"
            ]
            [ text display ]
        , adjButton "+" (toMsg step)
        ]


adjButton : String -> msg -> Html msg
adjButton label msg =
    button
        [ onClick msg
        , style "width" "22px"
        , style "height" "22px"
        , style "background" "#1a1a24"
        , style "color" "#e0e0ec"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "4px"
        , style "cursor" "pointer"
        , style "font-family" "'JetBrains Mono', monospace"
        , style "font-size" "12px"
        , style "padding" "0"
        , style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        , attribute "aria-label" (label ++ " adjust")
        ]
        [ text label ]
