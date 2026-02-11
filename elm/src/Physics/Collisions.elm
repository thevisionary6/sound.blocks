module Physics.Collisions exposing (detectAndResolve)

import Dict exposing (Dict)
import Model exposing (..)
import Physics.SAT


type alias CollisionResult =
    { bodies : Dict BodyId Body
    , events : List CollisionEvent
    }


type alias CollisionInfo =
    { normal : Vec2
    , overlap : Float
    }


detectAndResolve : CollisionMode -> Int -> Dict BodyId Body -> CollisionResult
detectAndResolve mode stepCount bodies =
    case mode of
        NoCollisions ->
            { bodies = bodies, events = [] }

        SimpleCollisions ->
            resolveAll False stepCount bodies

        EnergeticCollisions ->
            resolveAll True stepCount bodies


resolveAll : Bool -> Int -> Dict BodyId Body -> CollisionResult
resolveAll trackEnergy stepCount bodies =
    let
        bodyList =
            Dict.values bodies

        pairs =
            makePairs bodyList
    in
    List.foldl (resolvePair trackEnergy stepCount) { bodies = bodies, events = [] } pairs


makePairs : List Body -> List ( BodyId, BodyId )
makePairs bodies =
    case bodies of
        [] ->
            []

        b :: rest ->
            List.map (\other -> ( b.id, other.id )) rest
                ++ makePairs rest


resolvePair : Bool -> Int -> ( BodyId, BodyId ) -> CollisionResult -> CollisionResult
resolvePair trackEnergy stepCount ( idA, idB ) result =
    case ( Dict.get idA result.bodies, Dict.get idB result.bodies ) of
        ( Just a, Just b ) ->
            resolveBodyPair trackEnergy stepCount a b result

        _ ->
            result


resolveBodyPair : Bool -> Int -> Body -> Body -> CollisionResult -> CollisionResult
resolveBodyPair trackEnergy stepCount a b result =
    let
        delta =
            vecSub b.pos a.pos

        dist =
            vecLen delta

        broadPhase =
            bodyRadius a + bodyRadius b
    in
    if dist > broadPhase then
        result

    else
        case detectCollision a b delta dist of
            Nothing ->
                result

            Just info ->
                applyCollisionResponse trackEnergy stepCount a b info result


detectCollision : Body -> Body -> Vec2 -> Float -> Maybe CollisionInfo
detectCollision a b delta dist =
    case ( a.shape, b.shape ) of
        ( Poly polyA, Poly polyB ) ->
            let
                worldA =
                    transformPoints a.pos a.rot polyA.points

                worldB =
                    transformPoints b.pos b.rot polyB.points
            in
            Physics.SAT.polyVsPoly worldA worldB
                |> Maybe.map (\c -> { normal = c.normal, overlap = c.depth })

        ( Circle { r }, Poly poly ) ->
            let
                worldPts =
                    transformPoints b.pos b.rot poly.points
            in
            Physics.SAT.circleVsPoly a.pos r worldPts
                |> Maybe.map (\c -> { normal = c.normal, overlap = c.depth })

        ( Poly poly, Circle { r } ) ->
            let
                worldPts =
                    transformPoints a.pos a.rot poly.points
            in
            Physics.SAT.circleVsPoly b.pos r worldPts
                |> Maybe.map
                    (\c ->
                        { normal = vecScale -1 c.normal
                        , overlap = c.depth
                        }
                    )

        _ ->
            let
                minDist =
                    shapeEffectiveRadius a + shapeEffectiveRadius b
            in
            if dist < minDist && dist > 0.001 then
                Just
                    { normal = vecNorm delta
                    , overlap = minDist - dist
                    }

            else
                Nothing


transformPoints : Vec2 -> Float -> List Vec2 -> List Vec2
transformPoints pos rot points =
    if abs rot < 0.001 then
        List.map (\p -> vecAdd pos p) points

    else
        let
            cosR =
                cos rot

            sinR =
                sin rot
        in
        List.map
            (\p ->
                { x = pos.x + p.x * cosR - p.y * sinR
                , y = pos.y + p.x * sinR + p.y * cosR
                }
            )
            points


applyCollisionResponse : Bool -> Int -> Body -> Body -> CollisionInfo -> CollisionResult -> CollisionResult
applyCollisionResponse trackEnergy stepCount a b info result =
    let
        normal =
            info.normal

        overlap =
            info.overlap

        totalMass =
            a.mass + b.mass

        sepA =
            overlap * (b.mass / totalMass)

        sepB =
            overlap * (a.mass / totalMass)

        newPosA =
            vecSub a.pos (vecScale sepA normal)

        newPosB =
            vecAdd b.pos (vecScale sepB normal)

        relVel =
            vecSub a.vel b.vel

        dvn =
            vecDot relVel normal
    in
    if dvn > 0 then
        let
            newBodies =
                result.bodies
                    |> Dict.insert a.id { a | pos = newPosA }
                    |> Dict.insert b.id { b | pos = newPosB }
        in
        { result | bodies = newBodies }

    else
        let
            restitution =
                min a.restitution b.restitution

            j =
                -(1 + restitution) * dvn / (1 / a.mass + 1 / b.mass)

            impulseVecA =
                vecScale (j / a.mass) normal

            impulseVecB =
                vecScale (j / b.mass) normal

            newVelA =
                vecAdd a.vel impulseVecA

            newVelB =
                vecSub b.vel impulseVecB

            tangentVel =
                vecSub relVel (vecScale dvn normal)

            tangentLen =
                vecLen tangentVel

            ( fricVelA, fricVelB ) =
                if tangentLen > 0.01 then
                    let
                        tangent =
                            vecScale (1 / tangentLen) tangentVel

                        mu =
                            min a.friction b.friction

                        jt =
                            min (mu * abs j) (tangentLen * (a.mass * b.mass / totalMass))

                        fricA =
                            vecSub newVelA (vecScale (jt / a.mass) tangent)

                        fricB =
                            vecAdd newVelB (vecScale (jt / b.mass) tangent)
                    in
                    ( fricA, fricB )

                else
                    ( newVelA, newVelB )

            contactPoint =
                vecAdd a.pos (vecScale (bodyRadius a) normal)

            rA =
                vecSub contactPoint a.pos

            rB =
                vecSub contactPoint b.pos

            crossA =
                rA.x * impulseVecA.y - rA.y * impulseVecA.x

            crossB =
                rB.x * impulseVecB.y - rB.y * impulseVecB.x

            inertiaA =
                bodyInertia a

            inertiaB =
                bodyInertia b

            newAngVelA =
                if inertiaA > 0 then
                    a.angVel + crossA / inertiaA

                else
                    a.angVel

            newAngVelB =
                if inertiaB > 0 then
                    b.angVel - crossB / inertiaB

                else
                    b.angVel

            collisionEnergy =
                abs dvn * (a.mass * b.mass / totalMass)

            newA =
                { a
                    | pos = newPosA
                    , vel = fricVelA
                    , angVel = newAngVelA
                    , energy =
                        if trackEnergy then
                            a.energy + collisionEnergy * 0.5

                        else
                            a.energy
                }

            newB =
                { b
                    | pos = newPosB
                    , vel = fricVelB
                    , angVel = newAngVelB
                    , energy =
                        if trackEnergy then
                            b.energy + collisionEnergy * 0.5

                        else
                            b.energy
                }

            newBodies =
                result.bodies
                    |> Dict.insert a.id newA
                    |> Dict.insert b.id newB

            event =
                { a = a.id
                , b = BodyTarget b.id
                , position = contactPoint
                , normal = normal
                , impulse = j
                , energy = collisionEnergy
                , timeStep = stepCount
                }
        in
        { bodies = newBodies
        , events = event :: result.events
        }


shapeEffectiveRadius : Body -> Float
shapeEffectiveRadius body =
    case body.shape of
        Circle { r } ->
            r

        Rect { w, h } ->
            min w h / 2

        Pipe { length, diameter } ->
            min length diameter / 2

        Poly { boundingR } ->
            boundingR


bodyInertia : Body -> Float
bodyInertia body =
    case body.shape of
        Circle { r } ->
            0.5 * body.mass * r * r

        Rect { w, h } ->
            body.mass * (w * w + h * h) / 12

        Pipe { length, diameter } ->
            body.mass * (length * length + diameter * diameter) / 12

        Poly { boundingR } ->
            0.5 * body.mass * boundingR * boundingR
