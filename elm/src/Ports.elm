port module Ports exposing (sendAudioEvent)

import Json.Encode as Encode


port audioEvent : Encode.Value -> Cmd msg


sendAudioEvent :
    { eventType : String
    , energy : Float
    , x : Float
    , y : Float
    , a : Int
    , b : Int
    , step : Int
    }
    -> Cmd msg
sendAudioEvent event =
    audioEvent
        (Encode.object
            [ ( "type", Encode.string event.eventType )
            , ( "energy", Encode.float event.energy )
            , ( "x", Encode.float event.x )
            , ( "y", Encode.float event.y )
            , ( "a", Encode.int event.a )
            , ( "b", Encode.int event.b )
            , ( "step", Encode.int event.step )
            ]
        )
