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

import Sha1 exposing (timestamp)
import Types exposing (..)
import Trees
import TreeUtils exposing (..)


main : Program Json.Value
main =
  App.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


port saveModel : Json.Encode.Value -> Cmd msg
port activateCards : List (List String) -> Cmd msg
port export : Json.Encode.Value -> Cmd msg


-- MODEL


type alias Model =
  { contents : Dict String Content
  , nodes : Dict String Node
  , trees : List Tree
  , viewState : ViewState
  }


defaultModel : Model
defaultModel =
  { contents = Dict.fromList [("defaultContentId", defaultContent)]
  , nodes = Dict.fromList [("defaultNodeId", defaultNode)]
  , trees = [Trees.defaultTree]
  , viewState = 
      { active = "0"
      , activePast = []
      , activeFuture = []
      , descendants = []
      , editing = Nothing
      , field = ""
      }
  }


init : Json.Value -> (Model, Cmd Msg)
init _ =
  defaultModel ! []


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
      { model
        | viewState = { vs | active = id }
      }
        ! [activateCards [[id]]]

    -- === Card Editing ===

    OpenCard id str ->
      { model
        | viewState = 
            { vs 
              | editing = Just id
              , field = str
            }
      }
        ! [focus id]

    UpdateField str ->
      { model
        | viewState = { vs | field = str }
      }
        ! []

    UpdateCard id str ->
      let
        node_ = Dict.get id model.nodes
        parentId_ = node_ ? defaultNode |> .parentId
        prevSiblingId_ = getPrevId id model.trees
        nextSiblingId_ = getNextId id model.trees

        -- get position of prev | minInt
        -- get position of next | maxInt
        -- newPosition = nextPos / 2 + prevPos / 2

        ops = []
      in
      if node_ == Nothing then
        model ! []
      else
        { model
          | trees = Trees.applyOperations ops model.trees
        }
          ! []


    -- === External Inputs ===

    ExternalCommand (cmd, arg) ->
      case cmd of
        "keyboard" ->
          model ! [run (HandleKey arg)]
        _ ->
          let
            db1 = Debug.log "Unknown external command" cmd
          in
          model ! []

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

        "mod+enter" ->
          editMode model
            (\uid -> UpdateCard uid vs.field)

        "enter" ->
          normalMode model
            (OpenCard vs.active "TODO: getContent")

        "esc" ->
          editMode model (\_ -> CancelCard )

        "mod+backspace" ->
          normalMode model
            (DeleteCard vs.active)

        "mod+j" ->
          normalMode model
            (InsertBelow vs.active)

        "mod+k" ->
          normalMode model
            (InsertAbove vs.active)

        "mod+l" ->
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




-- VIEW


view : Model -> Html Msg
view model =
  (lazy2 Trees.view model.viewState model.trees)




-- SUBSCRIPTIONS

port externals : ((String, String) -> msg) -> Sub msg -- ~ Sub (String, String)
port opsIn : (Json.Encode.Value -> msg) -> Sub msg -- ~ Sub Op


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ externals ExternalCommand
    , opsIn OpIn
    ]




-- HELPERS

focus : String -> Cmd Msg
focus uid =
  Task.perform (\_ -> NoOp) (\_ -> NoOp) (Dom.focus ("card-edit-" ++ uid))
      


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
