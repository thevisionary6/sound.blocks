module Physics.SAT exposing (polyVsPoly, circleVsPoly)

import Model exposing (Vec2, vecAdd, vecDot, vecLen, vecNorm, vecScale, vecSub)


type alias Collision =
    { normal : Vec2
    , depth : Float
    }


polyVsPoly : List Vec2 -> List Vec2 -> Maybe Collision
polyVsPoly vertsA vertsB =
    let
        axesA =
            edgeNormals vertsA

        axesB =
            edgeNormals vertsB

        allAxes =
            axesA ++ axesB
    in
    checkAllAxes allAxes vertsA vertsB Nothing


circleVsPoly : Vec2 -> Float -> List Vec2 -> Maybe Collision
circleVsPoly center radius verts =
    let
        closest =
            closestPointOnPoly center verts

        delta =
            vecSub center closest

        dist =
            vecLen delta
    in
    if dist < radius && dist > 0.001 then
        let
            normal =
                vecNorm delta
        in
        Just { normal = normal, depth = radius - dist }

    else if isInsidePoly center verts then
        let
            ( bestNormal, bestDist ) =
                closestEdgeToPoint center verts

            depth =
                radius + bestDist
        in
        Just { normal = vecScale -1 bestNormal, depth = depth }

    else
        Nothing


edgeNormals : List Vec2 -> List Vec2
edgeNormals verts =
    let
        pairs =
            List.map2 Tuple.pair verts (List.drop 1 verts ++ List.take 1 verts)
    in
    List.map
        (\( a, b ) ->
            let
                edge =
                    vecSub b a
            in
            vecNorm { x = -edge.y, y = edge.x }
        )
        pairs


checkAllAxes : List Vec2 -> List Vec2 -> List Vec2 -> Maybe Collision -> Maybe Collision
checkAllAxes axes vertsA vertsB best =
    case axes of
        [] ->
            best

        axis :: rest ->
            let
                ( minA, maxA ) =
                    projectOntoAxis axis vertsA

                ( minB, maxB ) =
                    projectOntoAxis axis vertsB

                overlap =
                    min maxA maxB - max minA minB
            in
            if overlap <= 0 then
                Nothing

            else
                let
                    newBest =
                        case best of
                            Nothing ->
                                Just { normal = axis, depth = overlap }

                            Just prev ->
                                if overlap < prev.depth then
                                    Just { normal = axis, depth = overlap }

                                else
                                    best
                in
                checkAllAxes rest vertsA vertsB newBest


projectOntoAxis : Vec2 -> List Vec2 -> ( Float, Float )
projectOntoAxis axis verts =
    case verts of
        [] ->
            ( 0, 0 )

        first :: rest ->
            let
                firstProj =
                    vecDot first axis
            in
            List.foldl
                (\v ( mn, mx ) ->
                    let
                        p =
                            vecDot v axis
                    in
                    ( min mn p, max mx p )
                )
                ( firstProj, firstProj )
                rest


closestPointOnPoly : Vec2 -> List Vec2 -> Vec2
closestPointOnPoly point verts =
    let
        pairs =
            List.map2 Tuple.pair verts (List.drop 1 verts ++ List.take 1 verts)
    in
    List.foldl
        (\( a, b ) best ->
            let
                cp =
                    closestPointOnSegment point a b

                d =
                    vecLen (vecSub point cp)

                bestD =
                    vecLen (vecSub point best)
            in
            if d < bestD then
                cp

            else
                best
        )
        (case verts of
            first :: _ ->
                first

            [] ->
                { x = 0, y = 0 }
        )
        pairs


closestPointOnSegment : Vec2 -> Vec2 -> Vec2 -> Vec2
closestPointOnSegment p a b =
    let
        ab =
            vecSub b a

        ap =
            vecSub p a

        abLen2 =
            vecDot ab ab
    in
    if abLen2 < 0.0001 then
        a

    else
        let
            t =
                clamp 0 1 (vecDot ap ab / abLen2)
        in
        vecAdd a (vecScale t ab)


isInsidePoly : Vec2 -> List Vec2 -> Bool
isInsidePoly point verts =
    let
        pairs =
            List.map2 Tuple.pair verts (List.drop 1 verts ++ List.take 1 verts)

        crossings =
            List.foldl
                (\( a, b ) count ->
                    if (a.y <= point.y && b.y > point.y) || (b.y <= point.y && a.y > point.y) then
                        let
                            t =
                                (point.y - a.y) / (b.y - a.y)

                            ix =
                                a.x + t * (b.x - a.x)
                        in
                        if point.x < ix then
                            count + 1

                        else
                            count

                    else
                        count
                )
                0
                pairs
    in
    modBy 2 crossings == 1


closestEdgeToPoint : Vec2 -> List Vec2 -> ( Vec2, Float )
closestEdgeToPoint point verts =
    let
        pairs =
            List.map2 Tuple.pair verts (List.drop 1 verts ++ List.take 1 verts)
    in
    List.foldl
        (\( a, b ) ( bestNormal, bestDist ) ->
            let
                edge =
                    vecSub b a

                normal =
                    vecNorm { x = -edge.y, y = edge.x }

                d =
                    abs (vecDot (vecSub point a) normal)
            in
            if d < bestDist then
                ( normal, d )

            else
                ( bestNormal, bestDist )
        )
        ( { x = 0, y = -1 }, 99999 )
        pairs
