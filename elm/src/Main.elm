module Main exposing (main)

import Browser
import Dict
import Html exposing (..)
import Html.Attributes exposing (style)
import Html.Events
import Json.Decode as Decode
import Model exposing (..)
import Update exposing (Msg(..), subscriptions, update)
import View.A11y exposing (viewAnnouncement, viewEventLog)
import Mixer exposing (MixerMsg)
import View.Controls exposing (viewControls)
import View.Inspector exposing (viewInspector)
import View.ConstraintPanel exposing (viewConstraintPanel)
import View.MaterialPanel exposing (viewMaterialPanel)
import View.MixerPanel exposing (viewMixerPanel)
import View.PropertiesPanel exposing (viewPropertiesPanel)
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
            , togglePanel = TogglePanel
            , undo = Undo
            , redo = Redo
            , zoomIn = ZoomIn
            , zoomOut = ZoomOut
            , zoomReset = ZoomReset
            , setMode = SetMode
            }
        , div
            [ style "flex" "1"
            , style "display" "flex"
            , style "justify-content" "center"
            , style "align-items" "center"
            , style "padding" "16px"
            , style "position" "relative"
            , onWheel
            ]
            [ viewWorld model svgMsgToMsg
            , viewPanelOverlay model
            ]
        , viewInspector model
        , viewEventLog model.log
        ]


onWheel : Html.Attribute Msg
onWheel =
    Html.Events.preventDefaultOn "wheel"
        (Decode.map (\dy -> ( WheelZoom dy, True ))
            (Decode.field "deltaY" Decode.float)
        )


svgMsgToMsg : View.Svg.Msg -> Msg
svgMsgToMsg svgMsg =
    SvgMsg svgMsg


viewPanelOverlay : Model -> Html Msg
viewPanelOverlay model =
    case model.ui.panel of
        NoPanel ->
            text ""

        MaterialPanel ->
            viewMaterialPanel
                model.ui.activeMaterial
                SelectMaterial
                (TogglePanel MaterialPanel)

        PropertiesPanel ->
            case model.ui.selected of
                Just id ->
                    case Dict.get id model.bodies of
                        Just body ->
                            viewPropertiesPanel
                                body
                                AdjustProperty
                                (TogglePanel PropertiesPanel)

                        Nothing ->
                            text ""

                Nothing ->
                    div
                        [ style "position" "absolute"
                        , style "top" "60px"
                        , style "right" "16px"
                        , style "background" "#13131a"
                        , style "border" "1px solid #2a2a3a"
                        , style "border-radius" "8px"
                        , style "padding" "12px"
                        , style "z-index" "100"
                        , style "font-size" "12px"
                        , style "color" "#7a7a8e"
                        ]
                        [ text "Select a body first." ]

        ConstraintPanel ->
            viewConstraintPanel
                model.ui.linkCreation
                model.links
                model.bodies
                StartLinkCreation
                DeleteLink
                CancelLinkCreation
                (TogglePanel ConstraintPanel)

        MixerPanel ->
            viewMixerPanel
                model.mixer
                MixerUpdate
                (TogglePanel MixerPanel)
