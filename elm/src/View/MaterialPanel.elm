module View.MaterialPanel exposing (viewMaterialPanel)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Material exposing (Material, allMaterials)


viewMaterialPanel : String -> (String -> msg) -> msg -> Html msg
viewMaterialPanel activeName selectMsg closeMsg =
    div
        [ style "position" "absolute"
        , style "top" "60px"
        , style "left" "16px"
        , style "background" "#13131a"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "8px"
        , style "padding" "12px"
        , style "z-index" "100"
        , style "min-width" "200px"
        , attribute "role" "dialog"
        , attribute "aria-label" "Material selector"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-bottom" "8px"
            ]
            [ span
                [ style "color" "#e0e0ec"
                , style "font-size" "13px"
                , style "font-weight" "500"
                ]
                [ text "Materials" ]
            , button
                [ onClick closeMsg
                , style "background" "none"
                , style "border" "none"
                , style "color" "#7a7a8e"
                , style "cursor" "pointer"
                , style "font-size" "14px"
                , attribute "aria-label" "Close material panel"
                ]
                [ text "x" ]
            ]
        , div
            [ style "display" "grid"
            , style "grid-template-columns" "1fr 1fr"
            , style "gap" "6px"
            ]
            (List.map (materialSwatch activeName selectMsg) allMaterials)
        ]


materialSwatch : String -> (String -> msg) -> Material -> Html msg
materialSwatch activeName selectMsg mat =
    let
        isActive =
            mat.name == activeName
    in
    button
        [ onClick (selectMsg mat.name)
        , style "display" "flex"
        , style "align-items" "center"
        , style "gap" "8px"
        , style "padding" "6px 10px"
        , style "background"
            (if isActive then
                "#2a2a3a"

             else
                "#1a1a24"
            )
        , style "border"
            (if isActive then
                "1px solid " ++ mat.color

             else
                "1px solid #2a2a3a"
            )
        , style "border-radius" "6px"
        , style "cursor" "pointer"
        , style "color" "#e0e0ec"
        , style "font-family" "inherit"
        , style "font-size" "11px"
        , attribute "aria-label" (mat.name ++ " material")
        , attribute "aria-pressed"
            (if isActive then
                "true"

             else
                "false"
            )
        ]
        [ div
            [ style "width" "16px"
            , style "height" "16px"
            , style "border-radius" "3px"
            , style "background" mat.color
            , style "opacity" (String.fromFloat mat.alpha)
            , style "flex-shrink" "0"
            ]
            []
        , span [] [ text mat.name ]
        ]
