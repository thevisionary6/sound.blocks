module Physics.Energy exposing (decayEnergy, totalKineticEnergy, bodyKineticEnergy)

import Dict exposing (Dict)
import Model exposing (..)


decayEnergy : Float -> Dict BodyId Body -> Dict BodyId Body
decayEnergy factor bodies =
    Dict.map
        (\_ body ->
            let
                newEnergy =
                    body.energy * factor
            in
            { body
                | energy =
                    if newEnergy < 0.01 then
                        0

                    else
                        newEnergy
            }
        )
        bodies


bodyKineticEnergy : Body -> Float
bodyKineticEnergy body =
    0.5 * body.mass * (vecDot body.vel body.vel)


totalKineticEnergy : Dict BodyId Body -> Float
totalKineticEnergy bodies =
    Dict.foldl (\_ body acc -> acc + bodyKineticEnergy body) 0 bodies
