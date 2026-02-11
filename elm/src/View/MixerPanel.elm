module View.MixerPanel exposing (viewMixerPanel)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Mixer exposing (MixerMsg(..), MixerState)


viewMixerPanel : MixerState -> (MixerMsg -> msg) -> msg -> Html msg
viewMixerPanel mixer toMsg closeMsg =
    div
        [ style "position" "absolute"
        , style "top" "8px"
        , style "right" "8px"
        , style "background" "#13131a"
        , style "border" "1px solid #2a2a3a"
        , style "border-radius" "8px"
        , style "padding" "12px"
        , style "z-index" "100"
        , style "min-width" "220px"
        , style "max-height" "500px"
        , style "overflow-y" "auto"
        , attribute "role" "dialog"
        , attribute "aria-label" "Audio mixer panel"
        ]
        [ header closeMsg
        , masterSection mixer toMsg
        , meterPlaceholder
        , reverbSection mixer toMsg
        , delaySection mixer toMsg
        ]


header : msg -> Html msg
header closeMsg =
    div
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
            [ text "Mixer" ]
        , button
            [ onClick closeMsg
            , style "background" "none"
            , style "border" "none"
            , style "color" "#7a7a8e"
            , style "cursor" "pointer"
            , style "font-size" "14px"
            , attribute "aria-label" "Close mixer panel"
            ]
            [ text "x" ]
        ]


masterSection : MixerState -> (MixerMsg -> msg) -> Html msg
masterSection mixer toMsg =
    div [ style "margin-bottom" "10px" ]
        [ sectionLabel "Master"
        , sliderRow "Volume"
            mixer.masterVolume
            0
            100
            (\s ->
                toMsg
                    (SetVolume
                        (String.toFloat s
                            |> Maybe.withDefault mixer.masterVolume
                            |> (\v -> v / 100)
                        )
                    )
            )
            (String.fromInt (round (mixer.masterVolume * 100)) ++ "%")
        , div [ style "margin-top" "4px" ]
            [ toggleButton "Mute"
                mixer.masterMuted
                (toMsg ToggleMute)
            ]
        ]


meterPlaceholder : Html msg
meterPlaceholder =
    div
        [ style "margin-bottom" "10px"
        , style "padding" "6px"
        , style "background" "#0a0a0f"
        , style "border-radius" "4px"
        ]
        [ div
            [ style "font-size" "9px"
            , style "color" "#5a5a6e"
            , style "margin-bottom" "3px"
            ]
            [ text "LEVEL" ]
        , div
            [ id "audio-meter"
            , style "height" "6px"
            , style "background" "#1a1a24"
            , style "border-radius" "3px"
            , style "overflow" "hidden"
            ]
            [ div
                [ id "audio-meter-bar"
                , style "height" "100%"
                , style "width" "0%"
                , style "background" "linear-gradient(to right, #55aa55, #aaaa55, #aa5555)"
                , style "transition" "width 0.1s ease-out"
                , style "border-radius" "3px"
                ]
                []
            ]
        ]


reverbSection : MixerState -> (MixerMsg -> msg) -> Html msg
reverbSection mixer toMsg =
    div [ style "margin-bottom" "10px" ]
        [ div [ style "display" "flex", style "align-items" "center", style "gap" "6px", style "margin-bottom" "4px" ]
            [ sectionLabel "Reverb"
            , toggleButton
                (if mixer.reverbEnabled then
                    "On"

                 else
                    "Off"
                )
                mixer.reverbEnabled
                (toMsg (SetReverbEnabled (not mixer.reverbEnabled)))
            ]
        , if mixer.reverbEnabled then
            div []
                [ sliderRow "Decay"
                    (mixer.reverbDecay / 3.0)
                    0
                    100
                    (\s ->
                        toMsg
                            (SetReverbDecay
                                (String.toFloat s
                                    |> Maybe.withDefault 50
                                    |> (\v -> v / 100 * 3.0)
                                )
                            )
                    )
                    (String.fromFloat (toFloat (round (mixer.reverbDecay * 10)) / 10) ++ "s")
                , sliderRow "Mix"
                    mixer.reverbMix
                    0
                    100
                    (\s ->
                        toMsg
                            (SetReverbMix
                                (String.toFloat s
                                    |> Maybe.withDefault 30
                                    |> (\v -> v / 100)
                                )
                            )
                    )
                    (String.fromInt (round (mixer.reverbMix * 100)) ++ "%")
                ]

          else
            text ""
        ]


delaySection : MixerState -> (MixerMsg -> msg) -> Html msg
delaySection mixer toMsg =
    div [ style "margin-bottom" "6px" ]
        [ div [ style "display" "flex", style "align-items" "center", style "gap" "6px", style "margin-bottom" "4px" ]
            [ sectionLabel "Delay"
            , toggleButton
                (if mixer.delayEnabled then
                    "On"

                 else
                    "Off"
                )
                mixer.delayEnabled
                (toMsg (SetDelayEnabled (not mixer.delayEnabled)))
            ]
        , if mixer.delayEnabled then
            div []
                [ sliderRow "Time"
                    ((mixer.delayTime - 0.05) / 0.95)
                    0
                    100
                    (\s ->
                        toMsg
                            (SetDelayTime
                                (String.toFloat s
                                    |> Maybe.withDefault 25
                                    |> (\v -> v / 100 * 0.95 + 0.05)
                                )
                            )
                    )
                    (String.fromFloat (toFloat (round (mixer.delayTime * 100)) / 100) ++ "s")
                , sliderRow "Feedback"
                    (mixer.delayFeedback / 0.9)
                    0
                    100
                    (\s ->
                        toMsg
                            (SetDelayFeedback
                                (String.toFloat s
                                    |> Maybe.withDefault 40
                                    |> (\v -> v / 100 * 0.9)
                                )
                            )
                    )
                    (String.fromInt (round (mixer.delayFeedback * 100)) ++ "%")
                , sliderRow "Mix"
                    mixer.delayMix
                    0
                    100
                    (\s ->
                        toMsg
                            (SetDelayMix
                                (String.toFloat s
                                    |> Maybe.withDefault 30
                                    |> (\v -> v / 100)
                                )
                            )
                    )
                    (String.fromInt (round (mixer.delayMix * 100)) ++ "%")
                ]

          else
            text ""
        ]



-- HELPERS


sectionLabel : String -> Html msg
sectionLabel label =
    span
        [ style "font-size" "11px"
        , style "font-weight" "500"
        , style "color" "#aaaabc"
        , style "text-transform" "uppercase"
        , style "letter-spacing" "0.5px"
        ]
        [ text label ]


sliderRow : String -> Float -> Float -> Float -> (String -> msg) -> String -> Html msg
sliderRow label normalizedValue minVal maxVal onChange displayVal =
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "gap" "6px"
        , style "margin" "3px 0"
        ]
        [ span
            [ style "font-size" "10px"
            , style "color" "#7a7a8e"
            , style "min-width" "50px"
            ]
            [ text label ]
        , input
            [ type_ "range"
            , Html.Attributes.min (String.fromFloat minVal)
            , Html.Attributes.max (String.fromFloat maxVal)
            , value (String.fromInt (round (normalizedValue * maxVal)))
            , onInput onChange
            , style "flex" "1"
            , style "height" "4px"
            , style "accent-color" "#ff6b3d"
            , attribute "aria-label" label
            ]
            []
        , span
            [ style "font-size" "9px"
            , style "color" "#5a5a6e"
            , style "min-width" "32px"
            , style "text-align" "right"
            , style "font-family" "'JetBrains Mono', monospace"
            ]
            [ text displayVal ]
        ]


toggleButton : String -> Bool -> msg -> Html msg
toggleButton label isActive msg =
    button
        [ onClick msg
        , style "padding" "2px 8px"
        , style "background"
            (if isActive then
                "#2a3a2a"

             else
                "#1a1a24"
            )
        , style "color"
            (if isActive then
                "#88cc88"

             else
                "#7a7a8e"
            )
        , style "border"
            ("1px solid "
                ++ (if isActive then
                        "#3a5a3a"

                    else
                        "#2a2a3a"
                   )
            )
        , style "border-radius" "3px"
        , style "cursor" "pointer"
        , style "font-size" "10px"
        , style "font-family" "inherit"
        , attribute "aria-pressed"
            (if isActive then
                "true"

             else
                "false"
            )
        , attribute "aria-label" label
        ]
        [ text label ]
