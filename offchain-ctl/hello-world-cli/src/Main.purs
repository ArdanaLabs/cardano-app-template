module Main
  ( main
  ) where

import Contract.Prelude
import UnitTest (helloUnitTest)
import Contract.Monad
  ( launchAff_
  , runContract_
  , configWithLogLevel
  )
import Contract.Wallet.KeyFile(mkKeyWalletFromFiles)
import Data.Log.Level (LogLevel(Trace))
import Serialization.Address (NetworkId(TestnetId))

main :: Effect Unit
main = launchAff_ $ pure unit
