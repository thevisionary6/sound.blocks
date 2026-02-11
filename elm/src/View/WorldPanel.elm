module View.WorldPanel exposing (WorldChange(..), viewWorldPanel)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Model exposing (..)


type WorldChange
    = AdjGravityX Float
    | AdjGravityY Float
    | AdjDamping Float
    | AdjEnergyDecay Float
    | AdjEnergyTransfer Float


viewWorldPanel : Constraints -> (WorldChange -> msg) -> msg -> Html msg
viewWorldPanel constraints changeMsg closeMsg =
    div
        [ style "position" "absolute"
        , style "top" "60px"
        , style "right" "16px"
        , style "background" "#13131a"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "8px"
        , style "padding" "12px"
        , style "z-index" "100"
        , style "min-width" "240px"
        , style "font-family" "'JetBrains Mono', monospace"
        , style "font-size" "11px"
        , attribute "role" "dialog"
        , attribute "aria-label" "World constants"
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
                [ text "World Constants" ]
            , button
                [ onClick closeMsg
                , style "background" "none"
                , style "border" "none"
                , style "color" "#7a7a8e"
                , style "cursor" "pointer"
                , style "font-size" "14px"
                , attribute "aria-label" "Close world panel"
                ]
                [ text "x" ]
            ]
        , sectionLabel "Gravity"
        , adjRow "Grav X" (round constraints.gravity.x) 50 (\d -> changeMsg (AdjGravityX d))
        , adjRow "Grav Y" (round constraints.gravity.y) 50 (\d -> changeMsg (AdjGravityY d))
        , sectionLabel "Physics"
        , adjRowFloat "Damping" constraints.damping 0.005 (\d -> changeMsg (AdjDamping d))
        , sectionLabel "Energy"
        , adjRowFloat "Decay" constraints.energyDecay 0.01 (\d -> changeMsg (AdjEnergyDecay d))
        , adjRowFloat "Transfer" constraints.energyTransferRate 0.02 (\d -> changeMsg (AdjEnergyTransfer d))
        ]


sectionLabel : String -> Html msg
sectionLabel label =
    div
        [ style "color" "#7a7a8e"
        , style "font-size" "9px"
        , style "text-transform" "uppercase"
        , style "letter-spacing" "1px"
        , style "margin-top" "8px"
        , style "margin-bottom" "4px"
        ]
        [ text label ]


adjRow : String -> Int -> Float -> (Float -> msg) -> Html msg
adjRow label val step toMsg =
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "margin-bottom" "4px"
        , style "gap" "4px"
        ]
        [ span
            [ style "color" "#7a7a8e"
            , style "min-width" "70px"
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


adjRowFloat : String -> Float -> Float -> (Float -> msg) -> Html msg
adjRowFloat label val step toMsg =
    let
        display =
            String.fromFloat (toFloat (round (val * 1000)) / 1000)
    in
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "margin-bottom" "4px"
        , style "gap" "4px"
        ]
        [ span
            [ style "color" "#7a7a8e"
            , style "min-width" "70px"
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
