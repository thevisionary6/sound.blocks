module View.A11y exposing (viewAnnouncement, viewEventLog)

import Html exposing (..)
import Html.Attributes exposing (..)
import Model exposing (..)


viewAnnouncement : String -> Html msg
viewAnnouncement announcement =
    div
        [ style "position" "absolute"
        , style "width" "1px"
        , style "height" "1px"
        , style "overflow" "hidden"
        , style "clip" "rect(0,0,0,0)"
        , attribute "role" "status"
        , attribute "aria-live" "polite"
        , attribute "aria-atomic" "true"
        ]
        [ text announcement ]


viewEventLog : EventLog -> Html msg
viewEventLog log =
    let
        items =
            List.take 5 log.announcements
    in
    div
        [ style "padding" "8px 16px"
        , style "background" "#0f0f17"
        , style "border-top" "1px solid #1a1a2a"
        , style "font-size" "11px"
        , style "font-family" "'JetBrains Mono', monospace"
        , style "color" "#7a7a8e"
        , style "max-height" "80px"
        , style "overflow-y" "auto"
        , attribute "role" "log"
        , attribute "aria-label" "Event log"
        , attribute "aria-live" "polite"
        ]
        (if List.isEmpty items then
            [ span [] [ text "No events yet." ] ]

         else
            List.map
                (\msg ->
                    div [ style "padding" "1px 0" ] [ text msg ]
                )
                items
        )
