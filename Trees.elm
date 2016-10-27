module Trees exposing (..)

import String
import List.Extra as ListExtra
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (lazy)
import Json.Decode as Json
import Markdown

import Types exposing (..)
import TreeUtils exposing (..)



-- MODEL

defaultTree =
  { id = "defaultTree"
  , content = defaultContent
  , parentId = Nothing
  , position = 0
  , children = Children []
  }




-- UPDATE

type TreeMsg
  = NoOp
  | Apply Op


update : TreeMsg -> List Tree -> List Tree
update msg trees =
  case msg of
    NoOp -> trees

    Apply op ->
      case op of
        Ins id content parentId_ position updated ->
          trees

        Del id ->
          trees


applyOperations : List Op -> List Tree -> List Tree
applyOperations ops trees =
  List.foldl applyOp trees ops


applyOp : Op -> List Tree -> List Tree
applyOp op trees =
  update (Apply op) trees




-- VIEW

view : ViewState -> List Tree -> Html Msg
view vstate trees =
  let
    columns =
      [[[]]] ++
      getColumns([[ trees ]]) ++
      [[[]]]
        |> List.map (viewColumn vstate)
  in
  div [ id "app" 
      , classList [ ("editing", vstate.editing /= Nothing) ]
      ]
    ( columns
    )


viewColumn : ViewState -> Column -> Html Msg
viewColumn vstate col =
  let
    buffer =
      [div [ class "buffer" ][]]
  in
  div
    [ class "column" ]
    ( buffer ++
      (List.map (lazy (viewGroup vstate)) col) ++
      buffer
    )
    


viewGroup : ViewState -> Group -> Html Msg
viewGroup vstate xs =
  let
    firstChild = 
      xs
        |> List.head
        |> Maybe.withDefault defaultTree
        |> .id

    isActiveDescendant =
      vstate.descendants
        |> List.member firstChild
  in
    div [ classList [ ("group", True)
                    , ("active-descendant", isActiveDescendant)
                    ]
        ]
        (List.map (lazy (viewCard vstate)) xs)


viewCard : ViewState -> Tree -> Html Msg
viewCard vstate tree =
  let
    isEditing = vstate.editing == Just tree.id
    isActive = vstate.active == tree.id

    options =
      { githubFlavored = Just { tables = True, breaks = True }
      , defaultHighlighting = Nothing
      , sanitize = False
      , smartypants = False
      }

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
        , value content
        --, onBlur CancelCard
        , onInput UpdateField
        ]
        []

    normalControls =
      if isActive then
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
                , onClick (OpenCard tree.id tree.content.content)
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
      else
        []
  in
  if isEditing then
    div [ id ("card-" ++ tree.id)
        , classList [ ("card", True)
                    , ("active", True)
                    , ("editing", isEditing)
                    , ("has-children", hasChildren)
                    ]
        ]
        [ tarea vstate.field
        , div [ class "flex-column card-right-overlay"]
              [ span 
                [ class "card-btn save"
                , title "Save Changes (Ctrl+Enter)"
                , onClick (UpdateCard tree.id vstate.field)
                ]
                []
              ]
        ]
  else
    div [ id ("card-" ++ tree.id)
        , classList [ ("card", True)
                    , ("active", isActive)
                    , ("editing", isEditing)
                    , ("has-children", hasChildren)
                    ]
        ]
        (
          [ div [ class "view" 
                , onClick (Activate tree.id)
                , onDoubleClick (OpenCard tree.id tree.content.content)
                ] [ Markdown.toHtmlWith options [] tree.content.content ]
          , tarea tree.content.content
          ] ++
          normalControls
        )

