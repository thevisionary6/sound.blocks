module View.Inspector exposing (viewInspector)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Model exposing (..)


viewInspector : Model -> Html msg
viewInspector model =
    let
        content =
            case model.ui.selected of
                Nothing ->
                    [ span [ style "color" "#7a7a8e" ]
                        [ text "No body selected. Use Tab in Select mode to cycle through bodies." ]
                    ]

                Just id ->
                    case Dict.get id model.bodies of
                        Nothing ->
                            [ span [ style "color" "#7a7a8e" ]
                                [ text "Selected body no longer exists." ]
                            ]

                        Just body ->
                            viewBodyDetails body
    in
    div
        [ style "padding" "10px 16px"
        , style "background" "#13131a"
        , style "border-top" "1px solid #2a2a3a"
        , style "font-size" "12px"
        , style "font-family" "'JetBrains Mono', monospace"
        , style "color" "#e0e0ec"
        , style "min-height" "80px"
        , attribute "role" "region"
        , attribute "aria-label" "Body inspector"
        , attribute "aria-live" "polite"
        ]
        content


viewBodyDetails : Body -> List (Html msg)
viewBodyDetails body =
    [ div [ style "margin-bottom" "4px", style "color" "#ff6b3d" ]
        [ text (bodyLabel body) ]
    , viewProp "Shape" (shapeDescription body.shape)
    , viewProp "Position"
        (String.fromInt (round body.pos.x)
            ++ ", "
            ++ String.fromInt (round body.pos.y)
        )
    , viewProp "Velocity"
        (String.fromInt (round body.vel.x)
            ++ ", "
            ++ String.fromInt (round body.vel.y)
        )
    , viewProp "Mass" (floatToStr 2 body.mass)
    , viewProp "Energy" (floatToStr 1 body.energy)
    , if List.isEmpty body.tags then
        text ""

      else
        viewProp "Tags" (String.join ", " body.tags)
    ]


viewProp : String -> String -> Html msg
viewProp label value =
    div [ style "display" "flex", style "gap" "8px" ]
        [ span [ style "color" "#7a7a8e", style "min-width" "80px" ] [ text (label ++ ":") ]
        , span [] [ text value ]
        ]


shapeDescription : Shape -> String
shapeDescription shape =
    case shape of
        Circle { r } ->
            "Circle (r=" ++ String.fromInt (round r) ++ ")"

        Rect { w, h } ->
            "Rect (" ++ String.fromInt (round w) ++ "x" ++ String.fromInt (round h) ++ ")"


floatToStr : Int -> Float -> String
floatToStr decimals val =
    let
        factor =
            toFloat (10 ^ decimals)

        rounded =
            toFloat (round (val * factor)) / factor
    in
    String.fromFloat rounded
