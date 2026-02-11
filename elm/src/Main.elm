module Main exposing (main)

import Browser
import Dict
import Html exposing (..)
import Html.Attributes exposing (style)
import Model exposing (..)
import Update exposing (Msg(..), subscriptions, update)
import View.A11y exposing (viewAnnouncement, viewEventLog)
import View.Controls exposing (viewControls)
import View.Inspector exposing (viewInspector)
import View.Svg exposing (viewWorld)


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


view : Model -> Html Msg
view model =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "height" "100vh"
        , style "background" "#0a0a0f"
        , style "color" "#e0e0ec"
        , style "font-family" "'Outfit', sans-serif"
        ]
        [ viewAnnouncement (currentAnnouncement model)
        , viewControls model
            { toggleRun = ToggleRun
            , toggleMode = ToggleMode
            , clear = Clear
            , setDrawTool = SetDrawTool
            , setBoundaryMode = SetBoundaryMode
            , setCollisionMode = SetCollisionMode
            }
        , div
            [ style "flex" "1"
            , style "display" "flex"
            , style "justify-content" "center"
            , style "align-items" "center"
            , style "padding" "16px"
            ]
            [ viewWorld model svgMsgToMsg ]
        , viewInspector model
        , viewEventLog model.log
        ]


svgMsgToMsg : View.Svg.Msg -> Msg
svgMsgToMsg svgMsg =
    case svgMsg of
        View.Svg.ClickBody id ->
            ClickBody id

        View.Svg.NoOp ->
            ToggleRun
