module Material exposing
    ( Material
    , SoundProfile
    , allMaterials
    , defaultMaterial
    , getMaterial
    , materialColor
    , materialNames
    , stone, wood, metal, rubber, glass, ice
    )

import Dict exposing (Dict)


type alias SoundProfile =
    { oscillatorType : String
    , baseFrequency : Float
    , decayTime : Float
    , noiseAmount : Float
    }


type alias Material =
    { name : String
    , density : Float
    , friction : Float
    , restitution : Float
    , color : String
    , alpha : Float
    , sound : SoundProfile
    }


stone : Material
stone =
    { name = "Stone"
    , density = 2.5
    , friction = 0.6
    , restitution = 0.3
    , color = "#8a8a9a"
    , alpha = 0.9
    , sound = { oscillatorType = "sine", baseFrequency = 120, decayTime = 0.08, noiseAmount = 0.5 }
    }


wood : Material
wood =
    { name = "Wood"
    , density = 0.8
    , friction = 0.5
    , restitution = 0.4
    , color = "#c47d3f"
    , alpha = 0.9
    , sound = { oscillatorType = "square", baseFrequency = 200, decayTime = 0.12, noiseAmount = 0.3 }
    }


metal : Material
metal =
    { name = "Metal"
    , density = 7.8
    , friction = 0.3
    , restitution = 0.6
    , color = "#9ab8d4"
    , alpha = 0.95
    , sound = { oscillatorType = "triangle", baseFrequency = 440, decayTime = 0.3, noiseAmount = 0.0 }
    }


rubber : Material
rubber =
    { name = "Rubber"
    , density = 1.1
    , friction = 0.9
    , restitution = 0.85
    , color = "#d44a4a"
    , alpha = 0.85
    , sound = { oscillatorType = "sine", baseFrequency = 80, decayTime = 0.05, noiseAmount = 0.0 }
    }


glass : Material
glass =
    { name = "Glass"
    , density = 2.4
    , friction = 0.2
    , restitution = 0.5
    , color = "#7ad4e6"
    , alpha = 0.6
    , sound = { oscillatorType = "sine", baseFrequency = 800, decayTime = 0.25, noiseAmount = 0.1 }
    }


ice : Material
ice =
    { name = "Ice"
    , density = 0.9
    , friction = 0.05
    , restitution = 0.4
    , color = "#c4e8f0"
    , alpha = 0.7
    , sound = { oscillatorType = "sine", baseFrequency = 500, decayTime = 0.15, noiseAmount = 0.4 }
    }


allMaterials : List Material
allMaterials =
    [ stone, wood, metal, rubber, glass, ice ]


materialNames : List String
materialNames =
    List.map .name allMaterials


materialDict : Dict String Material
materialDict =
    List.foldl (\m d -> Dict.insert m.name m d) Dict.empty allMaterials


getMaterial : String -> Material
getMaterial name =
    Dict.get name materialDict
        |> Maybe.withDefault defaultMaterial


defaultMaterial : Material
defaultMaterial =
    rubber


materialColor : String -> String
materialColor name =
    (getMaterial name).color
