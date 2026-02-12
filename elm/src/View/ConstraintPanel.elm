module View.ConstraintPanel exposing (viewConstraintPanel)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Model exposing (..)


viewConstraintPanel :
    LinkCreation
    -> Dict LinkId Link
    -> Dict BodyId Body
    -> (LinkKind -> msg)
    -> (LinkId -> msg)
    -> msg
    -> msg
    -> Html msg
viewConstraintPanel creation links bodies startCreate deleteLink cancelCreate closeMsg =
    div
        [ style "position" "absolute"
        , style "top" "8px"
        , style "right" "8px"
        , style "background" "#13131a"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "8px"
        , style "padding" "12px"
        , style "z-index" "100"
        , style "min-width" "200px"
        , style "max-height" "400px"
        , style "overflow-y" "auto"
        , attribute "role" "dialog"
        , attribute "aria-label" "Constraints panel"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-bottom" "10px"
            ]
            [ span
                [ style "font-size" "13px"
                , style "font-weight" "500"
                , style "color" "#e0e0ec"
                ]
                [ text "Constraints" ]
            , button
                [ onClick closeMsg
                , style "background" "none"
                , style "border" "none"
                , style "color" "#7a7a8e"
                , style "cursor" "pointer"
                , style "font-size" "14px"
                , attribute "aria-label" "Close constraints panel"
                ]
                [ text "x" ]
            ]
        , viewCreationStatus creation cancelCreate
        , div
            [ style "display" "grid"
            , style "grid-template-columns" "1fr 1fr"
            , style "gap" "4px"
            , style "margin-bottom" "10px"
            ]
            [ linkTypeButton "String" "#88aa55" (creation == NotCreating) (startCreate (StringLink { length = 0 }))
            , linkTypeButton "Spring" "#55aa88" (creation == NotCreating) (startCreate (SpringLink { restLength = 0, stiffness = 100 }))
            , linkTypeButton "Rope" "#aa8855" (creation == NotCreating) (startCreate (RopeLink { maxLength = 0 }))
            , linkTypeButton "Weld" "#aa5555" (creation == NotCreating) (startCreate (WeldLink { relativeOffset = { x = 0, y = 0 } }))
            ]
        , viewLinkList links bodies deleteLink
        ]


viewCreationStatus : LinkCreation -> msg -> Html msg
viewCreationStatus creation cancelCreate =
    case creation of
        NotCreating ->
            text ""

        PickingFirst _ ->
            div
                [ style "background" "#1a2a1a"
                , style "border" "1px solid #2a4a2a"
                , style "border-radius" "4px"
                , style "padding" "8px"
                , style "margin-bottom" "8px"
                , style "font-size" "11px"
                , style "color" "#88cc88"
                ]
                [ text "Click the first body..."
                , br [] []
                , button
                    [ onClick cancelCreate
                    , style "margin-top" "4px"
                    , style "background" "#2a2a3a"
                    , style "border" "1px solid #3a3a4a"
                    , style "border-radius" "3px"
                    , style "color" "#7a7a8e"
                    , style "cursor" "pointer"
                    , style "font-size" "10px"
                    , style "padding" "2px 6px"
                    ]
                    [ text "Cancel" ]
                ]

        PickingSecond _ bodyA ->
            div
                [ style "background" "#1a2a1a"
                , style "border" "1px solid #2a4a2a"
                , style "border-radius" "4px"
                , style "padding" "8px"
                , style "margin-bottom" "8px"
                , style "font-size" "11px"
                , style "color" "#88cc88"
                ]
                [ text ("Body " ++ String.fromInt bodyA ++ " selected.")
                , br [] []
                , text "Click the second body..."
                , br [] []
                , button
                    [ onClick cancelCreate
                    , style "margin-top" "4px"
                    , style "background" "#2a2a3a"
                    , style "border" "1px solid #3a3a4a"
                    , style "border-radius" "3px"
                    , style "color" "#7a7a8e"
                    , style "cursor" "pointer"
                    , style "font-size" "10px"
                    , style "padding" "2px 6px"
                    ]
                    [ text "Cancel" ]
                ]


linkTypeButton : String -> String -> Bool -> msg -> Html msg
linkTypeButton label color enabled msg =
    button
        [ onClick msg
        , disabled (not enabled)
        , style "padding" "6px 8px"
        , style "background"
            (if enabled then
                "#1a1a24"

             else
                "#0f0f15"
            )
        , style "color" color
        , style "border" ("1px solid " ++ color)
        , style "border-radius" "4px"
        , style "cursor"
            (if enabled then
                "pointer"

             else
                "not-allowed"
            )
        , style "font-size" "11px"
        , style "font-family" "inherit"
        , style "opacity"
            (if enabled then
                "1"

             else
                "0.4"
            )
        , attribute "aria-label" ("Create " ++ label ++ " constraint")
        ]
        [ text label ]


viewLinkList : Dict LinkId Link -> Dict BodyId Body -> (LinkId -> msg) -> Html msg
viewLinkList links bodies deleteLink =
    let
        linkList =
            Dict.values links
    in
    if List.isEmpty linkList then
        div
            [ style "font-size" "11px"
            , style "color" "#5a5a6e"
            , style "text-align" "center"
            , style "padding" "8px"
            ]
            [ text "No constraints yet." ]

    else
        div []
            [ div
                [ style "font-size" "10px"
                , style "color" "#7a7a8e"
                , style "margin-bottom" "4px"
                ]
                [ text ("Active (" ++ String.fromInt (List.length linkList) ++ ")") ]
            , div [ style "display" "flex", style "flex-direction" "column", style "gap" "3px" ]
                (List.map (viewLinkItem bodies deleteLink) linkList)
            ]


viewLinkItem : Dict BodyId Body -> (LinkId -> msg) -> Link -> Html msg
viewLinkItem bodies deleteLink link =
    let
        kindLabel =
            linkKindLabel link.kind

        nameA =
            Dict.get link.bodyA bodies
                |> Maybe.map bodyLabel
                |> Maybe.withDefault ("Body " ++ String.fromInt link.bodyA)

        nameB =
            Dict.get link.bodyB bodies
                |> Maybe.map bodyLabel
                |> Maybe.withDefault ("Body " ++ String.fromInt link.bodyB)

        color =
            linkKindColor link.kind
    in
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "gap" "6px"
        , style "padding" "4px 6px"
        , style "background" "#0f0f17"
        , style "border-radius" "3px"
        , style "font-size" "10px"
        ]
        [ span [ style "color" color, style "font-weight" "500" ]
            [ text kindLabel ]
        , span [ style "color" "#7a7a8e", style "flex" "1" ]
            [ text (nameA ++ " - " ++ nameB) ]
        , button
            [ onClick (deleteLink link.id)
            , style "background" "none"
            , style "border" "none"
            , style "color" "#aa4444"
            , style "cursor" "pointer"
            , style "font-size" "10px"
            , style "padding" "0 2px"
            , attribute "aria-label" ("Delete " ++ kindLabel ++ " constraint")
            ]
            [ text "x" ]
        ]


linkKindLabel : LinkKind -> String
linkKindLabel kind =
    case kind of
        StringLink _ ->
            "String"

        SpringLink _ ->
            "Spring"

        RopeLink _ ->
            "Rope"

        WeldLink _ ->
            "Weld"


linkKindColor : LinkKind -> String
linkKindColor kind =
    case kind of
        StringLink _ ->
            "#88aa55"

        SpringLink _ ->
            "#55aa88"

        RopeLink _ ->
            "#aa8855"

        WeldLink _ ->
            "#aa5555"
