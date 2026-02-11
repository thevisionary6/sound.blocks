module View.Controls exposing (viewControls)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Model exposing (..)


type alias ControlMsgs msg =
    { toggleRun : msg
    , toggleMode : msg
    , clear : msg
    , setDrawTool : DrawTool -> msg
    , setBoundaryMode : BoundaryMode -> msg
    , setCollisionMode : CollisionMode -> msg
    }


viewControls : Model -> ControlMsgs msg -> Html msg
viewControls model msgs =
    div
        [ style "padding" "12px 16px"
        , style "background" "#13131a"
        , style "border-bottom" "1px solid #2a2a3a"
        , style "display" "flex"
        , style "gap" "8px"
        , style "align-items" "center"
        , style "flex-wrap" "wrap"
        , style "font-size" "13px"
        , attribute "role" "toolbar"
        , attribute "aria-label" "Simulation controls"
        ]
        [ controlButton
            (if model.sim.running then
                "Pause (P)"

             else
                "Play (P)"
            )
            msgs.toggleRun
        , controlButton (modeButtonLabel model.ui.mode) msgs.toggleMode
        , controlButton "Clear" msgs.clear
        , span [ style "color" "#2a2a3a", style "margin" "0 4px" ] [ text "|" ]
        , viewDrawToolPicker model.ui.drawTool msgs.setDrawTool
        , span [ style "color" "#2a2a3a", style "margin" "0 4px" ] [ text "|" ]
        , viewBoundaryPicker model.constraints.boundaryMode msgs.setBoundaryMode
        , viewCollisionPicker model.constraints.collisionMode msgs.setCollisionMode
        , span
            [ style "color" "#7a7a8e"
            , style "margin-left" "auto"
            , style "font-family" "'JetBrains Mono', monospace"
            , style "font-size" "11px"
            ]
            [ text
                ("Bodies: "
                    ++ String.fromInt (Dict.size model.bodies)
                    ++ "  Step: "
                    ++ String.fromInt model.sim.stepCount
                )
            ]
        ]


modeButtonLabel : UiMode -> String
modeButtonLabel mode =
    case mode of
        DrawMode ->
            "Mode: Draw (D)"

        SelectMode ->
            "Mode: Select (S)"

        RunMode ->
            "Mode: Run (R)"

        InspectMode ->
            "Mode: Inspect (I)"


viewDrawToolPicker : DrawTool -> (DrawTool -> msg) -> Html msg
viewDrawToolPicker current setTool =
    span [ style "display" "flex", style "gap" "4px" ]
        [ toolButton "Circle" (current == CircleTool) (setTool CircleTool)
        , toolButton "Rect" (current == RectTool) (setTool RectTool)
        ]


viewBoundaryPicker : BoundaryMode -> (BoundaryMode -> msg) -> Html msg
viewBoundaryPicker current setMode =
    span [ style "display" "flex", style "gap" "4px" ]
        [ toolButton "Bounce" (current == Bounce) (setMode Bounce)
        , toolButton "Wrap" (current == Wrap) (setMode Wrap)
        , toolButton "Clamp" (current == Clamp) (setMode Clamp)
        ]


viewCollisionPicker : CollisionMode -> (CollisionMode -> msg) -> Html msg
viewCollisionPicker current setMode =
    span [ style "display" "flex", style "gap" "4px" ]
        [ toolButton "No Col" (current == NoCollisions) (setMode NoCollisions)
        , toolButton "Simple" (current == SimpleCollisions) (setMode SimpleCollisions)
        , toolButton "Energy" (current == EnergeticCollisions) (setMode EnergeticCollisions)
        ]


controlButton : String -> msg -> Html msg
controlButton label msg =
    button
        [ onClick msg
        , style "padding" "6px 14px"
        , style "background" "#1a1a24"
        , style "color" "#e0e0ec"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "6px"
        , style "font-family" "inherit"
        , style "font-size" "12px"
        , style "cursor" "pointer"
        , attribute "aria-label" label
        ]
        [ text label ]


toolButton : String -> Bool -> msg -> Html msg
toolButton label isActive msg =
    button
        [ onClick msg
        , style "padding" "4px 10px"
        , style "background"
            (if isActive then
                "#2a2a3a"

             else
                "#1a1a24"
            )
        , style "color"
            (if isActive then
                "#ff6b3d"

             else
                "#7a7a8e"
            )
        , style "border"
            (if isActive then
                "1px solid #ff6b3d"

             else
                "1px solid #2a2a3a"
            )
        , style "border-radius" "4px"
        , style "font-family" "inherit"
        , style "font-size" "11px"
        , style "cursor" "pointer"
        , attribute "aria-pressed"
            (if isActive then
                "true"

             else
                "false"
            )
        , attribute "aria-label" label
        ]
        [ text label ]
