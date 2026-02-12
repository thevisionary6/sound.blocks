module Physics.Energy exposing (decayEnergy, totalKineticEnergy, bodyKineticEnergy, transferEnergyThroughLinks)

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


transferEnergyThroughLinks : Float -> Dict LinkId Link -> Dict BodyId Body -> Dict BodyId Body
transferEnergyThroughLinks rate linkDict bodies =
    if rate < 0.001 then
        bodies

    else
        Dict.foldl (transferLink rate) bodies linkDict


transferLink : Float -> LinkId -> Link -> Dict BodyId Body -> Dict BodyId Body
transferLink rate _ link bodies =
    case ( Dict.get link.bodyA bodies, Dict.get link.bodyB bodies ) of
        ( Just a, Just b ) ->
            let
                diff =
                    a.energy - b.energy

                transfer =
                    diff * rate * 0.5
            in
            if abs transfer < 0.005 then
                bodies

            else
                bodies
                    |> Dict.insert a.id { a | energy = a.energy - transfer }
                    |> Dict.insert b.id { b | energy = b.energy + transfer }

        _ ->
            bodies


bodyKineticEnergy : Body -> Float
bodyKineticEnergy body =
    0.5 * body.mass * (vecDot body.vel body.vel)


totalKineticEnergy : Dict BodyId Body -> Float
totalKineticEnergy bodies =
    Dict.foldl (\_ body acc -> acc + bodyKineticEnergy body) 0 bodies
