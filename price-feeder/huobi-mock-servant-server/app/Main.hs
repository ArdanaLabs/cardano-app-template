module Main where

import Network.Wai.Handler.Warp (setPort, defaultSettings)
import Network.Wai.Handler.WarpTLS as Warp (runTLS, defaultTlsSettings)
import Options.Applicative

import Network.Huobi.Server.Mock (huobiMockApp)
import CLI (Serve(..), mockServerOptions)

main :: IO ()
main = do
  execParser (mockServerOptions "huobi") >>= \(Serve priceDataPath port) ->
    runTLS defaultTlsSettings (setPort port defaultSettings) (huobiMockApp priceDataPath)
