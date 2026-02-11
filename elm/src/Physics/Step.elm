module Physics.Step exposing (step)

import Dict exposing (Dict)
import Model exposing (..)
import Physics.Collisions
import Physics.ConstraintSolver
import Physics.Energy


type alias StepResult =
    { bodies : Dict BodyId Body
    , events : List CollisionEvent
    }


step : Constraints -> Bounds -> Int -> Dict LinkId Link -> Dict BodyId Body -> StepResult
step constraints bounds stepCount links bodies =
    let
        dt =
            1.0 / toFloat constraints.tickRateHz

        integrated =
            Dict.map (\_ b -> integrate constraints dt b) bodies

        constrained =
            Physics.ConstraintSolver.solve links dt integrated

        bounded =
            Dict.map (\_ b -> applyBoundary constraints.boundaryMode bounds b) constrained

        collisionResult =
            Physics.Collisions.detectAndResolve constraints.collisionMode stepCount bounded

        transferred =
            Physics.Energy.transferEnergyThroughLinks constraints.energyTransferRate links collisionResult.bodies

        decayed =
            Physics.Energy.decayEnergy constraints.energyDecay transferred
    in
    { bodies = decayed
    , events = collisionResult.events
    }


integrate : Constraints -> Float -> Body -> Body
integrate constraints dt body =
    let
        newVel =
            { x = (body.vel.x + constraints.gravity.x * dt) * constraints.damping
            , y = (body.vel.y + constraints.gravity.y * dt) * constraints.damping
            }

        newPos =
            { x = body.pos.x + newVel.x * dt
            , y = body.pos.y + newVel.y * dt
            }

        newRot =
            body.rot + body.angVel * dt

        newAngVel =
            body.angVel * constraints.damping
    in
    { body | pos = newPos, vel = newVel, rot = newRot, angVel = newAngVel }


applyBoundary : BoundaryMode -> Bounds -> Body -> Body
applyBoundary mode bounds body =
    case mode of
        Bounce ->
            boundaryBounce bounds body

        Wrap ->
            boundaryWrap bounds body

        Clamp ->
            boundaryClamp bounds body


boundaryBounce : Bounds -> Body -> Body
boundaryBounce bounds body =
    let
        r =
            bodyRadius body

        ( px, vx ) =
            clampAxisBounce r bounds.width body.pos.x body.vel.x

        ( py, vy ) =
            bounceFloor r bounds.height body.pos.y body.vel.y
    in
    { body
        | pos = { x = px, y = py }
        , vel = { x = vx, y = vy }
    }


clampAxisBounce : Float -> Float -> Float -> Float -> ( Float, Float )
clampAxisBounce radius limit pos vel =
    if pos - radius < 0 then
        ( radius, abs vel * 0.7 )

    else if pos + radius > limit then
        ( limit - radius, -(abs vel) * 0.7 )

    else
        ( pos, vel )


bounceFloor : Float -> Float -> Float -> Float -> ( Float, Float )
bounceFloor radius floorY pos vel =
    if pos + radius > floorY then
        ( floorY - radius, -(abs vel) * 0.7 )

    else
        ( pos, vel )


boundaryWrap : Bounds -> Body -> Body
boundaryWrap bounds body =
    let
        r =
            bodyRadius body

        wx =
            wrapAxis r bounds.width body.pos.x

        wy =
            if body.pos.y - r > bounds.height then
                -r

            else
                body.pos.y
    in
    { body | pos = { x = wx, y = wy } }


wrapAxis : Float -> Float -> Float -> Float
wrapAxis radius limit pos =
    if pos + radius < 0 then
        limit + radius

    else if pos - radius > limit then
        -radius

    else
        pos


boundaryClamp : Bounds -> Body -> Body
boundaryClamp bounds body =
    let
        r =
            bodyRadius body

        cx =
            clamp r (bounds.width - r) body.pos.x

        cy =
            min (bounds.height - r) body.pos.y

        vx =
            if body.pos.x - r < 0 || body.pos.x + r > bounds.width then
                0

            else
                body.vel.x

        vy =
            if body.pos.y + r > bounds.height then
                0

            else
                body.vel.y
    in
    { body
        | pos = { x = cx, y = cy }
        , vel = { x = vx, y = vy }
    }
