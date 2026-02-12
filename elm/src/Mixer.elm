module Mixer exposing
    ( MixerMsg(..)
    , MixerState
    , defaultMixer
    , updateMixer
    )


type alias MixerState =
    { masterVolume : Float
    , masterMuted : Bool
    , reverbEnabled : Bool
    , reverbDecay : Float
    , reverbMix : Float
    , delayEnabled : Bool
    , delayTime : Float
    , delayFeedback : Float
    , delayMix : Float
    }


defaultMixer : MixerState
defaultMixer =
    { masterVolume = 0.7
    , masterMuted = False
    , reverbEnabled = False
    , reverbDecay = 0.5
    , reverbMix = 0.3
    , delayEnabled = False
    , delayTime = 0.25
    , delayFeedback = 0.4
    , delayMix = 0.3
    }


type MixerMsg
    = SetVolume Float
    | ToggleMute
    | SetReverbEnabled Bool
    | SetReverbDecay Float
    | SetReverbMix Float
    | SetDelayEnabled Bool
    | SetDelayTime Float
    | SetDelayFeedback Float
    | SetDelayMix Float


updateMixer : MixerMsg -> MixerState -> MixerState
updateMixer msg mixer =
    case msg of
        SetVolume v ->
            { mixer | masterVolume = clamp 0 1 v }

        ToggleMute ->
            { mixer | masterMuted = not mixer.masterMuted }

        SetReverbEnabled on ->
            { mixer | reverbEnabled = on }

        SetReverbDecay v ->
            { mixer | reverbDecay = clamp 0.1 3.0 v }

        SetReverbMix v ->
            { mixer | reverbMix = clamp 0 1 v }

        SetDelayEnabled on ->
            { mixer | delayEnabled = on }

        SetDelayTime v ->
            { mixer | delayTime = clamp 0.05 1.0 v }

        SetDelayFeedback v ->
            { mixer | delayFeedback = clamp 0 0.9 v }

        SetDelayMix v ->
            { mixer | delayMix = clamp 0 1 v }
