module Test.HelloWorld.Discovery.Api
 ( spec
  ) where

import Contract.Prelude

import Contract.Test.Plutip (PlutipConfig, withPlutipContractEnv, runContractInEnv)
import Contract.Wallet (withKeyWallet)
import Data.BigInt as BigInt
import Data.UInt as UInt
import HelloWorld.Discovery.Api (mintNft)
import Test.Spec (Spec, describe, it)
import Util (withOurLogger)

config :: PlutipConfig
config =
  { host: "127.0.0.1"
  , port: UInt.fromInt 8082
  , logLevel: Error
  -- Server configs are used to deploy the corresponding services.
  , ogmiosConfig:
      { port: UInt.fromInt 1338
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , ogmiosDatumCacheConfig:
      { port: UInt.fromInt 10000
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , ctlServerConfig:
      { port: UInt.fromInt 8083
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , postgresConfig:
      { host: "127.0.0.1"
      , port: UInt.fromInt 5433
      , user: "ctxlib"
      , password: "ctxlib"
      , dbname: "ctxlib"
      }
  }

spec :: Spec Unit
spec = do
  describe "HelloWorld.Discovery.Api" $ do
    testInitialize

testInitialize :: Spec Unit
testInitialize = do
  describe "nft" do
    it "minting an nft should succeed" $ do
      let initialAdaAmount = BigInt.fromInt 20_000_000
      withPlutipContractEnv config [ initialAdaAmount ] \env alice -> do
        runContractInEnv (withOurLogger "./apiTest.log" env) $
          withKeyWallet alice do
            _ <- mintNft
            pure unit

