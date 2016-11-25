port module Main exposing (..)


import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2)
import String
import Dict exposing (Dict)
import Json.Encode
import Json.Decode as Json
import Dom
import Task
import Markdown
import List.Extra as ListExtra

import Types exposing (..)
import Trees exposing (update, view, defaultTree, blankTree)
import TreeUtils exposing (..)
import Coders exposing (modelDecoder, modelToValue)


main : Program Json.Value
main =
  App.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


port activateCards : (Int, List (List String)) -> Cmd msg
port message : (String, Json.Encode.Value) -> Cmd msg


-- MODEL


type alias Model =
  { tree : Tree
  , treePast : List Tree
  , treeFuture : List Tree
  , viewState : ViewState
  , nextId : Int
  , saved : Bool
  }


defaultModel : Model
defaultModel =
  { tree = defaultTree
  , treePast = []
  , treeFuture = []
  , viewState = 
      { active = "0"
      , activePast = []
      , activeFuture = []
      , descendants = []
      , editing = Just "0"
      , field = ""
      , stats = Dict.empty
      }
  , nextId = 1
  , saved = True
  }


init : Json.Value -> (Model, Cmd Msg)
init savedState =
  let
    activateCmd mdl =
      activateCards 
        ( getDepth 0 mdl.tree mdl.viewState.active
        , (centerlineIds 
          mdl.tree 
          (getTree mdl.viewState.active mdl.tree ? defaultTree) 
          mdl.viewState.activePast
          )
        )
  in
  case Json.decodeValue modelDecoder savedState of
    Ok model ->
      model 
        ! [ activateCmd model
          , focus model.viewState.active
          ]
    Err err ->
      let
        deb = Debug.log "init decode error" err
      in
      defaultModel 
        ! [ activateCmd defaultModel
          , focus defaultModel.viewState.active
          ]


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  let
    vs = model.viewState
  in
  case msg of
    NoOp ->
      model ! []

    -- === Card Activation ===

    Activate id ->
      let
        vs = model.viewState
        activeTree_ = getTree id model.tree
        newPast =
          case (id == vs.active) of
            True ->
              vs.activePast
            False ->
              vs.active :: vs.activePast |> List.take 40
      in
      case activeTree_ of
        Just activeTree ->
          let
            desc =
              activeTree
                |> getDescendants
                |> List.map .id

            newModel =
              { model
                | viewState = 
                  { vs
                    | active = id
                    , activePast = newPast
                    , activeFuture = []
                    , descendants = desc
                  }
              }
          in
          newModel
            ! [ activateCards 
                  ( getDepth 0 model.tree id
                  , (centerlineIds model.tree activeTree newPast)
                  )
              ]

        Nothing ->
          model ! []

    GoLeft id ->
      let
        targetId =
          getParent id model.tree ? defaultTree |> .id
      in
      update (Activate targetId) model

    GoDown id ->
      let
        targetId =
          case getNextInColumn id model.tree of
            Nothing -> id
            Just ntree -> ntree.id
      in
      update (Activate targetId) model

    GoUp id ->
      let
        targetId =
          case getPrevInColumn id model.tree of
            Nothing -> id
            Just ptree -> ptree.id
      in
      update (Activate targetId) model

    GoRight id ->
      let
        tree =
          getTree id model.tree

        childrenIds =
          getChildren (tree ? defaultTree)
            |> List.map .id

        firstChildId =
          childrenIds
            |> List.head
            |> Maybe.withDefault id

        prevActiveOfChildren =
          vs.activePast
            |> List.filter (\a -> List.member a childrenIds)
            |> List.head
            |> Maybe.withDefault firstChildId
      in
      case tree of
        Nothing ->
          model ! []
        Just t ->
          if List.length childrenIds == 0 then
            model ! []
          else
            update (Activate prevActiveOfChildren) model
      
    -- === Card Editing  ===

    OpenCard id str ->
      { model 
        | viewState = { vs | active = id, editing = Just id, field = str }
      } 
        ! [ focus id ]

    UpdateField str ->
      { model 
        | viewState = { vs | field = str }
      } 
        ! []

    UpdateCard id str ->
      { model
        | tree = Trees.update (Trees.Upd id str) model.tree
        , viewState = { vs | active = id, editing = Nothing, field = "" }
      }
        ! [] 
        |> andThen (AddToUndo model.tree)
        |> andThen SaveTemp

    SaveCard ->
      case vs.editing of
        Just editId ->
          let
            activeTree_ =
              getTree editId model.tree
          in
          case activeTree_ of
            Nothing ->
              update CancelCard model

            Just activeTree ->
              if activeTree.content /= vs.field then
                update (UpdateCard editId vs.field) model
              else
                update CancelCard model

        Nothing ->
          model ! []

    DeleteCard id ->
      let
        filteredActive =
          vs.activePast
            |> List.filter (\a -> a /= id)

        parent_ = getParent id model.tree
        prev_ = getPrevInColumn id model.tree
        next_ = getNextInColumn id model.tree

        nextToActivate =
          case (parent_, prev_, next_) of
            (_, Just prev, _) ->
              prev.id

            (_, Nothing, Just next) ->
              next.id

            (Just parent, Nothing, Nothing) ->
              parent.id

            (Nothing, Nothing, Nothing) ->
              "0"
      in
      { model
        | tree = Trees.update (Trees.Del id) model.tree
        , viewState = { vs | activePast = filteredActive }
      }
        ! []
        |> andThen (Activate nextToActivate)
        |> andThen (AddToUndo model.tree)
        |> andThen SaveTemp

    CancelCard ->
      { model 
        | viewState = { vs | editing = Nothing, field = "" }
      } 
        ! []


    -- === Card Insertion  ===

    Insert subtree pid idx ->
      let
        newId = subtree.id
      in
      { model
        | tree = Trees.update (Trees.Ins subtree pid idx) model.tree
        , nextId = model.nextId + 1
      }
        ! []
        |> andThen (OpenCard newId subtree.content)
        |> andThen (Activate newId)
        |> andThen (AddToUndo model.tree)
        |> andThen SaveTemp

    InsertAbove id ->
      let
        idx =
          getIndex id model.tree ? 999999

        pid_ =
          getParent id model.tree |> Maybe.map .id

        insertMsg =
          case pid_ of
            Nothing ->
              NoOp

            Just pid ->
              Insert (blankTree model.nextId) pid idx
      in
      case vs.editing of
        Nothing ->
          update insertMsg model

        Just id ->
          update SaveCard model
            |> andThen insertMsg

    InsertBelow id ->
      let
        idx =
          getIndex id model.tree ? 999999

        pid_ =
          getParent id model.tree |> Maybe.map .id

        insertMsg =
          case pid_ of
            Nothing ->
              NoOp

            Just pid ->
              Insert (blankTree model.nextId) pid (idx+1)
      in
      case vs.editing of
        Nothing ->
          update insertMsg model

        Just id ->
          update SaveCard model
            |> andThen insertMsg

    InsertChild pid ->
      let
        insertMsg =
          Insert (blankTree model.nextId) pid 999999
      in
      case vs.editing of
        Nothing ->
          update insertMsg model

        Just id ->
          update SaveCard model
            |> andThen insertMsg

    -- === Card Moving  ===

    Move subtree pid idx ->
      let
        newTree = Trees.update (Trees.Mov subtree pid idx) model.tree 
      in
      if newTree == model.tree then
        model ! []
      else
        { model
          | tree = newTree
          , saved = False
        }
          ! []
          |> andThen (AddToUndo model.tree)
          |> andThen (Activate subtree.id)
          |> andThen SaveTemp

    MoveUp id ->
      let
        tree_ =
          getTree id model.tree

        pid_ =
          getParent id model.tree
            |> Maybe.map .id

        refIdx_ =
          getIndex id model.tree
      in
      case (tree_, pid_, refIdx_) of
        (Just tree, Just pid, Just refIdx) ->
          update (Move tree pid (refIdx-1)) model
        _ ->
          model ! []

    MoveDown id ->
      let
        tree_ =
          getTree id model.tree

        pid_ =
          getParent id model.tree
            |> Maybe.map .id

        refIdx_ =
          getIndex id model.tree
      in
      case (tree_, pid_, refIdx_) of
        (Just tree, Just pid, Just refIdx) ->
          update (Move tree pid (refIdx+1)) model
        _ ->
          model ! []

    MoveLeft id ->
      let
        tree_ =
          getTree id model.tree

        parentId =
          getParent id model.tree
            |> Maybe.map .id
            |> Maybe.withDefault "invalid"

        parentIdx_ =
          getIndex parentId model.tree

        grandparentId_ =
          getParent parentId model.tree
            |> Maybe.map .id

      in
      case (tree_, grandparentId_, parentIdx_) of
        (Just tree, Just gpId, Just refIdx) ->
          update (Move tree gpId (refIdx+1)) model
        _ ->
          model ! []

    MoveRight id ->
      let
        tree_ =
          getTree id model.tree

        prev_ =
          getPrev id model.tree
            |> Maybe.map .id
      in
      case (tree_, prev_) of
        (Just tree, Just prev) ->
          update (Move tree prev 999999) model
        _ ->
          model ! []


    -- === History ===

    Undo ->
      let
        prevState_ = List.head model.treePast
      in
      case prevState_ of
        Nothing ->
          model ! []
        Just prevState ->
          let
            newModel =
              { model
                | tree = prevState
                , treePast = List.drop 1 model.treePast
                , treeFuture = model.tree :: model.treeFuture
              } 
          in
          newModel
            ! [ message ("undo-state-change", modelToValue newModel) ]

    Redo ->
      let
        nextState_ = List.head model.treeFuture
      in
      case nextState_ of
        Nothing ->
          model ! []
        Just nextState ->
          let
            newModel =
              { model
                | tree = nextState
                , treePast = model.tree :: model.treePast
                , treeFuture = List.drop 1 model.treeFuture
              } 
          in
          newModel
            ! [ message ("undo-state-change", modelToValue newModel) ]

    AddToUndo oldTree ->
      if oldTree == model.tree then
        model ! []
      else
        let
          newModel =
            { model
              | treePast = oldTree :: model.treePast |> List.take 20
              , treeFuture = []
            }
        in
        newModel
          ! [ message ("undo-state-change", modelToValue newModel) ]


    -- === Stats ===

    Keyboard msg ->
      let
        key =
          toString msg
            |> String.split " "
            |> List.head
            |> Maybe.withDefault "KeyboardTagError"

        incStat : Maybe (Int, Int) -> Maybe (Int, Int)
        incStat tup_ =
          case tup_ of
            Just (a, b) ->
              Just (a+1, b+1)

            Nothing -> Nothing

        newStats =
          if Dict.member key vs.stats then
            Dict.update key incStat vs.stats
          else
            Dict.insert key (1, 1) vs.stats
      in
        { model
          | viewState = { vs | stats = newStats }
        }
          ! []
            |> andThen msg

    Mouse msg ->
      let
        key =
          toString msg
            |> String.split " "
            |> List.head
            |> Maybe.withDefault "MouseTagError"

        incStat : Maybe (Int, Int) -> Maybe (Int, Int)
        incStat tup_ =
          case tup_ of
            Just (a, b) ->
              Just (a, b+1)

            Nothing -> Nothing

        newStats =
          if Dict.member key vs.stats then
            Dict.update key incStat vs.stats
          else
            Dict.insert key (0, 1) vs.stats
      in
        { model
          | viewState = { vs | stats = newStats }
        }
          ! []
            |> andThen msg


    -- === Ports ===

    SaveTemp ->
      let
        newModel =
          { model
            | saved = False
          }
      in
        newModel ! [ message ("save-temp", modelToValue newModel) ]

    Confirm tag title msg ->
      model
        ! [ message
            ( tag
            , Json.Encode.object  [ ("title", Json.Encode.string title)
                                  , ("message", Json.Encode.string msg)
                                  ]
            )
          ]

    ExternalCommand (cmd, arg) ->
      case cmd of
        "keyboard" ->
          model ! [run (HandleKey arg)]

        "confirm-cancel" ->
          if arg == "true" then
            update CancelCard model
          else
            model ! []

        _ ->
          let
            db1 = Debug.log "Unknown external command" cmd
          in
          model ! []

    DataIn json ->
      init json

    HandleKey str ->
      let
        vs = model.viewState
      in
      case str of
        "mod+x" ->
          let
            db1 = Debug.log "model" model
          in
          model ! []

        "mod+s" ->
          model ! [ message ("save", modelToValue model) ]

        "mod+enter" ->
          editMode model
            (\_ -> Keyboard SaveCard)

        "enter" ->
          normalMode model
            (Keyboard (OpenCard vs.active (getContent vs.active model.tree)))

        "esc" ->
          case vs.editing of
            Nothing ->
              model ! []

            Just uid ->
              let
                activeTree_ =
                  getTree uid model.tree
              in
              case activeTree_ of
                Nothing ->
                  model ! []

                Just activeTree ->
                  if activeTree.content /= vs.field then
                    update 
                    (Confirm "confirm-cancel" "Discard Changes?" "Are you sure you want to discard unsaved changes?")
                    model
                  else
                    update CancelCard model

        "mod+backspace" ->
          normalMode model
            (DeleteCard vs.active)

        "mod+j" ->
          update (InsertBelow vs.active) model

        "mod+down" ->
          normalMode model
            (InsertBelow vs.active)

        "mod+k" ->
          update (InsertAbove vs.active) model

        "mod+up" ->
          normalMode model
            (InsertAbove vs.active)

        "mod+l" ->
          update (InsertChild vs.active) model

        "mod+right" ->
          normalMode model
            (InsertChild vs.active)

        "h" ->
          normalMode model
            (GoLeft vs.active)

        "left" ->
          normalMode model
            (GoLeft vs.active)

        "j" ->
          normalMode model
            (GoDown vs.active)

        "down" ->
          normalMode model
            (GoDown vs.active)

        "k" ->
          normalMode model
            (GoUp vs.active)
  
        "up" ->
          normalMode model
            (GoUp vs.active)
  
        "l" ->
          normalMode model
            (GoRight vs.active)

        "right" ->
          normalMode model
            (GoRight vs.active)

        "alt+up" ->
          normalMode model
            (MoveUp vs.active)

        "alt+down" ->
          normalMode model
            (MoveDown vs.active)

        "alt+left" ->
          normalMode model
            (MoveLeft vs.active)

        "alt+right" ->
          normalMode model
            (MoveRight vs.active)

        "mod+z" ->
          normalMode model Undo

        "mod+r" ->
          normalMode model Redo

        "[" ->
          normalMode model ActivatePast

        "]" ->
          normalMode model ActivateFuture

        other ->
          let
            deb = Debug.log "keyboard" other
          in
          model ! []

    _ ->
      model ! []


andThen : Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen msg (model, prevMsg) =
  let
    newStep =
      update msg model
  in
  ( fst newStep, Cmd.batch [prevMsg, snd newStep] )




-- VIEW


view : Model -> Html Msg
view model =
  (lazy2 Trees.view model.viewState model.tree)




-- SUBSCRIPTIONS

port externals : ((String, String) -> msg) -> Sub msg -- ~ Sub (String, String)
port data : (Json.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ externals ExternalCommand
    , data DataIn
    ]




-- HELPERS

focus : String -> Cmd Msg
focus id =
  Task.perform (\_ -> NoOp) (\_ -> NoOp) (Dom.focus ("card-edit-" ++ id))


run : Msg -> Cmd Msg
run msg =
  Task.perform (\_ -> NoOp) (\_ -> msg ) (Task.succeed msg)


editMode : Model -> (String -> Msg) -> (Model, Cmd Msg)
editMode model editing = 
  case model.viewState.editing of
    Nothing ->
      model ! []

    Just uid ->
      update (editing uid) model


normalMode : Model -> Msg -> (Model, Cmd Msg)
normalMode model msg = 
  case model.viewState.editing of
    Nothing ->
      update msg model

    Just _ ->
      model ! []
