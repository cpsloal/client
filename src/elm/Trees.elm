module Trees exposing (..)

import Dict exposing (Dict)
import Tuple exposing (first, second)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (lazy, lazy2, lazy3)
import Html.Keyed as Keyed
import Markdown

import Types exposing (..)
import TreeUtils exposing (..)



-- MODEL

type alias Model =
  { tree : Tree
  , columns : List Column
  , nodes : Dict String TreeNode
  , vertices : Dict String Vertex
  , edges : Dict String Edge
  }


defaultModel : Model
defaultModel =
  { tree = defaultTree
  , columns = getColumns [[[defaultTree]]]
  , nodes = Dict.fromList [("0", TreeNode "" [] Nothing False)]
  , vertices = Dict.fromList[("0", Vertex Nothing "")]
  , edges = Dict.empty
  }


defaultTree : Tree
defaultTree =
  { id = "0"
  , content = ""
  , children = Children []
  , rev = Nothing
  , deleted = False
  }


blankTree : String -> Int -> Tree
blankTree timeString time =
  { id = generateId timeString time
  , content = ""
  , children = Children []
  , rev = Nothing
  , deleted = False
  }




-- UPDATE

type TreeMsg
  = NoOp
  | Ins Tree String Int
  | Upd String String
  | Mov Tree String Int
  | Del String
  | Node String TreeNode
  | Edg String Edge
  | Vert String Vertex
  | GIns String String Vertex
  | GDel String
  | GUpd String String


update : TreeMsg -> Model -> Model
update msg model =
  case msg of
    Edg id edge ->
      let
        newEdges =
          Dict.insert id edge model.edges

        newTree =
          if newEdges /= model.edges then
            buildTree model.vertices newEdges "0"
          else
            model.tree

        newColumns =
          if newTree /= model.tree then
            getColumns [[[newTree]]]
          else
            model.columns
      in
      { model
        | tree = newTree
        , columns = newColumns
        , edges = newEdges
      }

    Vert id vertex ->
      let
        newVertices =
          Dict.insert id vertex model.vertices

        newTree =
          if newVertices /= model.vertices then
            buildTree newVertices model.edges "0"
          else
            model.tree

        newColumns =
          if newTree /= model.tree then
            getColumns [[[newTree]]]
          else
            model.columns
      in
      { model
        | tree = newTree
        , columns = newColumns
        , vertices = newVertices
      }

    _ ->
      let
        (newVertices, newEdges) =
          updateGraph msg (model.vertices, model.edges)

        newTree =
          if newVertices /= model.vertices || newEdges /= model.edges then
            buildTree newVertices newEdges "0"
          else
            model.tree

        newColumns =
          if newTree /= model.tree then
            getColumns [[[newTree]]]
          else
            model.columns
      in
      { model
        | tree = newTree
        , columns = newColumns
        , vertices = newVertices
        , edges = newEdges
      }


updateColumns : Model -> Model
updateColumns model =
  { model
    | columns = getColumns [[[ model.tree ]]]
  }


updateData : Model -> Model
updateData model =
  { model
    | columns = getColumns [[[ model.tree ]]]
    , nodes = getNodes model.tree
    , vertices = getVertices model.tree
    , edges = getEdges model.edges model.tree
  }


updateTree : TreeMsg -> Tree -> Tree
updateTree msg tree =
  case msg of
    NoOp -> tree

    Ins newTree parentId idx ->
      insertSubtree newTree parentId idx tree

    Upd id str ->
      modifyTree id (\t -> { t | content = str} ) tree

    Mov newTree parentId idx ->
      apply 
        [ Del newTree.id
        , Ins newTree parentId idx
        ]
      tree

    Del id ->
      pruneSubtree id tree

    _ ->
      tree


updateGraph : TreeMsg -> (Dict String Vertex, Dict String Edge) -> (Dict String Vertex, Dict String Edge)
updateGraph msg (vertices, edges) =
  case msg of
    NoOp -> (vertices, edges)

    GIns id pid vert ->
      let
        newVertices =
          Dict.insert id vert vertices

        newEdges =
          if Dict.member (edgeId pid id) edges then
            edges
          else
            Dict.insert (edgeId pid id) (Edge Nothing pid id) edges
      in
      ( newVertices, newEdges ) 

    GDel id ->
      (vertices, edges)

    GUpd id str ->
      let
        updFn vert_ =
          case vert_ of
            Just vert ->
              Just { vert | content = str }

            Nothing -> Nothing
      in
      ( Dict.update id updFn vertices, edges)

    _ ->
      (vertices, edges)



apply : List TreeMsg -> Tree -> Tree
apply msgs tree =
  List.foldl (\m t -> updateTree m t) tree msgs


insertSubtree : Tree -> String -> Int -> Tree -> Tree
insertSubtree subtree parentId idx tree =
  let
    fn = (\c -> (List.take idx c) ++ [subtree] ++ (List.drop idx c))
  in
  modifyChildren parentId fn tree


pruneSubtree : String -> Tree -> Tree
pruneSubtree id tree =
  modifySiblings id (\c -> List.filter (\x -> x.id /= id) c) tree


modifyTree : String -> (Tree -> Tree) -> Tree -> Tree
modifyTree id upd tree =
  if tree.id == id then
    upd tree
  else
    { tree
      | children =
          getChildren tree
            |> List.map (modifyTree id upd)
            |> Children
    }


modifyChildren : String -> (List Tree -> List Tree) -> Tree -> Tree
modifyChildren pid upd tree =
  if tree.id == pid then
    { tree
      | children =
          getChildren tree
            |> upd
            |> Children
    }
  else
    { tree
      | children =
          getChildren tree
            |> List.map (modifyChildren pid upd)
            |> Children
    }


modifySiblings : String -> (List Tree -> List Tree) -> Tree -> Tree
modifySiblings id upd tree =
  case getParent id tree of
    Nothing ->
      tree
    Just parentTree ->
      modifyChildren parentTree.id upd tree




-- VIEW

view : ViewState -> Model -> Html Msg
view vstate model =
  let
    columnsWithDepth =
      model.columns
        |> List.indexedMap (\i c -> (c, i))

    getViewArgs cwd =
      let
        editing_ =
          case vstate.editing of
            Nothing ->
              Nothing

            Just editId ->
              if (first cwd |> List.concat |> List.map .id |> List.member editId ) then
                Just editId
              else
                Nothing
      in
      VisibleViewState 
        vstate.active
        editing_
        vstate.descendants

    columns =
      [([[]], -1)] ++
      columnsWithDepth ++
      [([[]], List.length columnsWithDepth)]
        |> List.map (\t -> lazy3 viewColumn (getViewArgs t) (second t) (first t))
  in
  div [ id "app" 
      ]
    ( columns
    )


viewColumn : VisibleViewState -> Int -> Column -> Html Msg
viewColumn vstate depth col =
  let
    buffer =
      [div [ class "buffer" ][]]
  in
  div
    [ class "column" ]
    ( buffer ++
      (List.map (lazy3 viewGroup vstate depth) col) ++
      buffer
    )
    


viewGroup : VisibleViewState -> Int -> Group -> Html Msg
viewGroup vstate depth xs =
  let
    firstChild = 
      xs
        |> List.head
        |> Maybe.withDefault defaultTree
        |> .id

    isActiveDescendant =
      vstate.descendants
        |> List.member firstChild

    viewFunction t =
      let
        isActive =
          t.id == vstate.active

        isEditing =
          case vstate.editing of
            Just editId ->
              t.id == editId

            Nothing ->
              False
      in
      viewKeyedCard (isActive, isEditing, depth) t
  in
    Keyed.node "div"
      [ classList [ ("group", True)
                  , ("active-descendant", isActiveDescendant)
                  ]
      ]
      (List.map viewFunction xs)


viewKeyedCard : (Bool, Bool, Int) -> Tree -> (String, Html Msg)
viewKeyedCard tup tree =
  (tree.id, lazy2 viewCard tup tree)


viewCard : (Bool, Bool, Int) -> Tree -> Html Msg
viewCard (isActive, isEditing, depth) tree =
  let
    isRoot = tree.id == "0"


    hasChildren =
      case tree.children of
        Children c ->
          ( c
              |> List.length
          ) /= 0

    tarea content =
      textarea
        [ id ( "card-edit-" ++ tree.id )
        , classList [ ("edit", True)
                    , ("mousetrap", True)
                    ]
        , defaultValue content
        ]
        []

    buttons =
      case (isEditing, isActive, isRoot) of
        ( False, True, False ) ->
          [ div [ class "flex-row card-top-overlay" ]
                [ span
                  [ class "card-btn ins-above"
                  , title "Insert Above (Ctrl+K)"
                  , onClick (InsertAbove tree.id)
                  ]
                  [ text "+" ]
                ]
          , div [ class "flex-column card-right-overlay"]
                [ span 
                  [ class "card-btn delete"
                  , title "Delete Card (Ctrl+Backspace)"
                  , onClick (DeleteCard tree.id)
                  ]
                  []
                , span
                  [ class "card-btn ins-right"
                  , title "Add Child (Ctrl+L)"
                  , onClick (InsertChild tree.id)
                  ]
                  [ text "+" ]
                , span 
                  [ class "card-btn edit"
                  , title "Edit Card (Enter)"
                  , onClick (OpenCard tree.id tree.content)
                  ]
                  []
                ]
          , div [ class "flex-row card-bottom-overlay" ]
                [ span
                  [ class "card-btn ins-below"
                  , title "Insert Below (Ctrl+J)"
                  , onClick (InsertBelow tree.id)
                  ]
                  [ text "+" ]
                ]
          ]

        ( False, True, True ) ->
          [ div [ class "flex-column card-right-overlay"]
                [ span
                  [ class "card-btn ins-right"
                  , title "Add Child (Ctrl+L)"
                  , onClick (InsertChild tree.id)
                  ]
                  [ text "+" ]
                , span 
                  [ class "card-btn edit"
                  , title "Edit Card (Enter)"
                  , onClick (OpenCard tree.id tree.content)
                  ]
                  []
                ]
          ]

        ( True, _, _ ) ->
          [ div [ class "flex-column card-right-overlay"]
                [ span 
                  [ class "card-btn save"
                  , title "Save Changes (Ctrl+Enter)"
                  , onClick (AttemptUpdateCard tree.id)
                  ]
                  []
                ]
          ]

        _ ->
          []


    cardAttributes =
      [ id ("card-" ++ tree.id)
      , classList [ ("card", True)
                  , ("root", isRoot)
                  , ("active", isActive)
                  , ("editing", isEditing)
                  , ("has-children", hasChildren)
                  ]
      ]
  in
  if isEditing then
    div cardAttributes
      (
        [ tarea tree.content ]
        ++
        buttons
      )
  else
    div cardAttributes
      (
        buttons ++
        [ div
            [ class "view"
            , onClick (Activate tree.id)
            , onDoubleClick (OpenCard tree.id tree.content)
            ] 
            [( lazy viewContent tree.content )]
        ]
      )


viewContent : String -> Html Msg
viewContent content =
  let
    options =
      { githubFlavored = Just { tables = True, breaks = True }
      , defaultHighlighting = Nothing
      , sanitize = False
      , smartypants = False
      }
  in
  Markdown.toHtmlWith options
    [] content

