port module Ports exposing (sendAudioEvent, sendMixerCommand)

import Json.Encode as Encode


port audioEvent : Encode.Value -> Cmd msg


port mixerCommand : Encode.Value -> Cmd msg


sendAudioEvent :
    { eventType : String
    , energy : Float
    , x : Float
    , y : Float
    , a : Int
    , b : Int
    , step : Int
    , materialA : String
    , materialB : String
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
            , ( "materialA", Encode.string event.materialA )
            , ( "materialB", Encode.string event.materialB )
            ]
        )


sendMixerCommand :
    { command : String
    , volume : Float
    , muted : Bool
    , reverbEnabled : Bool
    , reverbDecay : Float
    , reverbMix : Float
    , delayEnabled : Bool
    , delayTime : Float
    , delayFeedback : Float
    , delayMix : Float
    }
    -> Cmd msg
sendMixerCommand cmd =
    mixerCommand
        (Encode.object
            [ ( "command", Encode.string cmd.command )
            , ( "volume", Encode.float cmd.volume )
            , ( "muted", Encode.bool cmd.muted )
            , ( "reverbEnabled", Encode.bool cmd.reverbEnabled )
            , ( "reverbDecay", Encode.float cmd.reverbDecay )
            , ( "reverbMix", Encode.float cmd.reverbMix )
            , ( "delayEnabled", Encode.bool cmd.delayEnabled )
            , ( "delayTime", Encode.float cmd.delayTime )
            , ( "delayFeedback", Encode.float cmd.delayFeedback )
            , ( "delayMix", Encode.float cmd.delayMix )
            ]
        )
