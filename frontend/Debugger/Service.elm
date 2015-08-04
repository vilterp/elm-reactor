module Debugger.Service where

import Signal
import Task
import Empty exposing (Empty)
import Components exposing (..)
import Debug
import Html exposing (div)

import Debugger.RuntimeApi as API
import Debugger.Active as Active


type alias Model =
  Maybe Active.Model


initModel : Model
initModel =
  Nothing


type Message
  = Initialized API.DebugSession API.ValueSet
  | ActiveMessage Active.Message


app : API.ElmModule -> App Message Model
app initMod =
  { init =
      let
        -- would be nice to pipeline this whole thing
        effect =
          API.initializeFullscreen
            initMod
            API.emptyInputHistory
            (Signal.forwardTo notificationsMailbox.address Active.NewFrame)
            API.justMain
          |> Task.map (\(session, values) -> Initialized session values)
          |> task
      in
        request effect Nothing
  , view = \_ _ -> div [] [] -- would be nice to not do this
  , update = update
  , externalMessages =
      [ Signal.map
          (ActiveMessage << Active.Notification)
          notificationsMailbox.signal
      , Signal.map
          (ActiveMessage << Active.Command)
          (commandsMailbox ()).signal
      ]
  }


-- TODO: there's an error if I make this a value instead of a function. Why?
commandsMailbox : () -> Signal.Mailbox Active.Command
commandsMailbox _ =
  mailbox


mailbox =
  Signal.mailbox Active.NoOpCommand


notificationsMailbox : Signal.Mailbox Active.Notification
notificationsMailbox =
  Signal.mailbox Active.NoOpNot


update : Message -> Model -> Transaction Message Model
update msg model =
  case Debug.log "SERVICE MSG" msg of
    Initialized session initValues ->
      case model of
        Just _ ->
          Debug.crash "already initialized"

        Nothing ->
          let
            initMain =
              Active.getMainVal session initValues
          in
            Active.initModel session initMain
              |> Just
              |> done

    ActiveMessage actMsg ->
      case model of
        Just activeModel ->
          with
            (tag ActiveMessage <| Active.update actMsg activeModel)
            (done << Just)

        Nothing ->
          Debug.crash "not yet initialized"