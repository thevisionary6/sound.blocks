module History exposing
    ( History
    , empty
    , push
    , undo
    , redo
    , canUndo
    , canRedo
    )


type alias History a =
    { past : List a
    , future : List a
    }


empty : History a
empty =
    { past = []
    , future = []
    }


maxDepth : Int
maxDepth =
    50


push : a -> History a -> History a
push snapshot history =
    { past = snapshot :: List.take (maxDepth - 1) history.past
    , future = []
    }


undo : a -> History a -> Maybe ( a, History a )
undo current history =
    case history.past of
        prev :: rest ->
            Just
                ( prev
                , { past = rest
                  , future = current :: history.future
                  }
                )

        [] ->
            Nothing


redo : a -> History a -> Maybe ( a, History a )
redo current history =
    case history.future of
        next :: rest ->
            Just
                ( next
                , { past = current :: history.past
                  , future = rest
                  }
                )

        [] ->
            Nothing


canUndo : History a -> Bool
canUndo history =
    not (List.isEmpty history.past)


canRedo : History a -> Bool
canRedo history =
    not (List.isEmpty history.future)
