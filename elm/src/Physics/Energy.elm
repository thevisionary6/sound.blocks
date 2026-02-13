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
        let
            -- Collect all transfer deltas from the INITIAL state (no stale refs)
            deltas =
                Dict.foldl (collectTransfer rate bodies) Dict.empty linkDict
        in
        Dict.map
            (\id body ->
                case Dict.get id deltas of
                    Just d ->
                        { body | energy = max 0 (body.energy + d) }

                    Nothing ->
                        body
            )
            bodies


collectTransfer : Float -> Dict BodyId Body -> LinkId -> Link -> Dict BodyId Float -> Dict BodyId Float
collectTransfer rate bodies _ link deltas =
    case ( Dict.get link.bodyA bodies, Dict.get link.bodyB bodies ) of
        ( Just a, Just b ) ->
            let
                diff =
                    a.energy - b.energy

                transfer =
                    diff * rate * 0.5
            in
            if abs transfer < 0.005 then
                deltas

            else
                deltas
                    |> addDelta a.id -transfer
                    |> addDelta b.id transfer

        _ ->
            deltas


addDelta : BodyId -> Float -> Dict BodyId Float -> Dict BodyId Float
addDelta id val deltas =
    Dict.update id (\existing -> Just (Maybe.withDefault 0 existing + val)) deltas


bodyKineticEnergy : Body -> Float
bodyKineticEnergy body =
    0.5 * body.mass * (vecDot body.vel body.vel)


totalKineticEnergy : Dict BodyId Body -> Float
totalKineticEnergy bodies =
    Dict.foldl (\_ body acc -> acc + bodyKineticEnergy body) 0 bodies
