module Physics.Resonance exposing (pipeResonantFreq, effectiveLength, speedOfSound)


speedOfSound : Float
speedOfSound =
    34300


pipeResonantFreq : Float -> ( Bool, Bool ) -> List Float -> Float
pipeResonantFreq length openEnds holes =
    let
        effLen =
            effectiveLength length openEnds holes
    in
    if effLen < 1 then
        1000

    else
        case openEnds of
            ( True, True ) ->
                speedOfSound / (2 * effLen)

            _ ->
                speedOfSound / (4 * effLen)


effectiveLength : Float -> ( Bool, Bool ) -> List Float -> Float
effectiveLength length openEnds holes =
    case List.minimum (List.map (\h -> h * length) holes) of
        Just firstHole ->
            case openEnds of
                ( True, _ ) ->
                    max 1 firstHole

                ( _, True ) ->
                    max 1 (length - firstHole)

                _ ->
                    max 1 firstHole

        Nothing ->
            length
