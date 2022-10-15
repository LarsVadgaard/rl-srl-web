{-# LANGUAGE OverloadedStrings #-}

module Server (server) where

import Web.Scotty
    ( file,
      get,
      json,
      middleware,
      notFound,
      param,
      post,
      rescue,
      scottyOpts,
      text,
      Options(..))
import System.Environment ( getEnv )
import System.Directory ( listDirectory )
import qualified Data.Text.Lazy as TL
import Network.Wai.Middleware.Static
    ( addBase, staticPolicy, noDots, (>->))
import Network.Wai.Handler.Warp ( setTimeout, setPort, defaultSettings )
import Data.List ( sort )

import qualified RL.Interface
import qualified SRL.Interface
import JSON
    ( ErrorResult(ErrorResult),
      RunResult(RunResult),
      VarTabContainer(VarTabContainer),
      badRequest )

server :: IO ()
server = do
  programs <- sort <$> listDirectory "./frontend/programs"
  port <- read <$> getEnv "PORT"
  
  let options = Options 1 $ (setTimeout 10 . setPort port) defaultSettings in
    scottyOpts options $ do
      -- serve frontend
      middleware $ staticPolicy (noDots >-> addBase "frontend")

      -- top domain
      get "/" $ file "./frontend/index.html"
      
      -- program list
      get "/programs" $ json programs
      
      -- help section
      get "/help" $ file "./frontend/help/index.html"

      -- api call
      post "/api" $ do
        lang <- TL.unpack <$> param "lang" `rescue` (\_ -> return "srl")
        script <- TL.unpack <$> param "script" `rescue` (\_ -> return "")
        mode <- TL.unpack <$> param "mode" `rescue` (\_ -> return "run")
        setLog <- TL.unpack <$> param "log" `rescue` (\_ -> return "false")
        case lang of
          "rl"  -> case mode of
            "run" ->
              let (res, trace) = RL.Interface.runProgram script in
              case res of
                Left err -> case setLog of
                  "true" -> json $ ErrorResult (err, trace) 
                  _      -> json err
                Right vtab -> case setLog of
                  "true" -> json $ RunResult (vtab, trace) 
                  _      -> json $ VarTabContainer vtab 
            "invert" ->
              case RL.Interface.invertProgram script of
                Left err -> json err
                Right program -> json program
            "translate" ->
              case RL.Interface.translateProgram script of
                Left err -> json err
                Right program -> json program
            _ -> json badRequest
          "srl" -> case mode of
            "run" ->
              let (res, trace) = SRL.Interface.runProgram script in
              case res of
                Left err -> case setLog of
                  "true" -> json $ ErrorResult (err, trace) 
                  _      -> json err
                Right vtab -> case setLog of
                  "true" -> json $ RunResult (vtab, trace) 
                  _ -> json $ VarTabContainer vtab 
            "invert" ->
              case SRL.Interface.invertProgram script of
                Left err -> json err
                Right program -> json program
            "translate" ->
              case SRL.Interface.translateProgram script of
                Left err -> json err
                Right program -> json program
            _ -> json badRequest
          _ -> json badRequest

      -- nothing matches
      notFound $ text "wrong route"
