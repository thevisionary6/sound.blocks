module Physics.ConstraintSolver exposing (solve)

import Dict exposing (Dict)
import Model exposing (..)


solve : Dict LinkId Link -> Float -> Dict BodyId Body -> Dict BodyId Body
solve linkDict dt bodies =
    let
        linkList =
            Dict.values linkDict
    in
    if List.isEmpty linkList then
        bodies

    else
        solveIterations 4 linkList dt bodies


solveIterations : Int -> List Link -> Float -> Dict BodyId Body -> Dict BodyId Body
solveIterations n linkList dt bodies =
    if n <= 0 then
        bodies

    else
        solveIterations (n - 1) linkList dt (List.foldl (solveLink dt) bodies linkList)


solveLink : Float -> Link -> Dict BodyId Body -> Dict BodyId Body
solveLink dt link bodies =
    case ( Dict.get link.bodyA bodies, Dict.get link.bodyB bodies ) of
        ( Just a, Just b ) ->
            solveLinkKind dt link.kind a b bodies

        _ ->
            bodies


solveLinkKind : Float -> LinkKind -> Body -> Body -> Dict BodyId Body -> Dict BodyId Body
solveLinkKind dt kind a b bodies =
    case kind of
        StringLink { length } ->
            solveString length a b bodies

        SpringLink { restLength, stiffness } ->
            solveSpring restLength stiffness dt a b bodies

        RopeLink { maxLength } ->
            solveString maxLength a b bodies

        WeldLink { relativeOffset } ->
            solveWeld relativeOffset a b bodies



-- STRING / ROPE: pull bodies together when dist > target


solveString : Float -> Body -> Body -> Dict BodyId Body -> Dict BodyId Body
solveString targetLength a b bodies =
    let
        delta =
            vecSub b.pos a.pos

        dist =
            vecLen delta
    in
    if dist > targetLength && dist > 0.001 then
        let
            normal =
                vecNorm delta

            excess =
                dist - targetLength

            invA =
                1 / a.mass

            invB =
                1 / b.mass

            invSum =
                invA + invB

            corrA =
                vecScale (excess * invA / invSum) normal

            corrB =
                vecScale (-(excess * invB / invSum)) normal
        in
        bodies
            |> Dict.insert a.id { a | pos = vecAdd a.pos corrA }
            |> Dict.insert b.id { b | pos = vecAdd b.pos corrB }

    else
        bodies



-- SPRING: Hooke's law applied as velocity impulse


solveSpring : Float -> Float -> Float -> Body -> Body -> Dict BodyId Body -> Dict BodyId Body
solveSpring restLength stiffness dt a b bodies =
    let
        delta =
            vecSub b.pos a.pos

        dist =
            vecLen delta

        displacement =
            dist - restLength
    in
    if abs displacement > 0.01 && dist > 0.001 then
        let
            normal =
                vecNorm delta

            -- Hooke's law: F = k * displacement
            -- Apply as velocity change: dv = F / m * dt
            -- Divided by 4 iterations for stability
            force =
                stiffness * displacement * dt / 4

            invA =
                1 / a.mass

            invB =
                1 / b.mass

            invSum =
                invA + invB

            impulseA =
                vecScale (force * invA / invSum) normal

            impulseB =
                vecScale (-(force * invB / invSum)) normal

            -- Apply damping to spring oscillation
            damp =
                0.98
        in
        bodies
            |> Dict.insert a.id { a | vel = vecScale damp (vecAdd a.vel impulseA) }
            |> Dict.insert b.id { b | vel = vecScale damp (vecAdd b.vel impulseB) }

    else
        bodies



-- WELD: maintain fixed offset


solveWeld : Vec2 -> Body -> Body -> Dict BodyId Body -> Dict BodyId Body
solveWeld offset a b bodies =
    let
        targetPos =
            vecAdd a.pos offset

        correction =
            vecSub targetPos b.pos

        invA =
            1 / a.mass

        invB =
            1 / b.mass

        invSum =
            invA + invB

        corrA =
            vecScale (-(invA / invSum)) correction

        corrB =
            vecScale (invB / invSum) correction

        -- Share velocities (weighted average)
        avgVel =
            { x = (a.vel.x * a.mass + b.vel.x * b.mass) / (a.mass + b.mass)
            , y = (a.vel.y * a.mass + b.vel.y * b.mass) / (a.mass + b.mass)
            }
    in
    bodies
        |> Dict.insert a.id { a | pos = vecAdd a.pos corrA, vel = avgVel }
        |> Dict.insert b.id { b | pos = vecAdd b.pos corrB, vel = avgVel }
