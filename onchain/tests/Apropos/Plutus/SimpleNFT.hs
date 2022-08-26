module Apropos.Plutus.SimpleNFT (spec) where

import Apropos
import Apropos.ContextBuilder
import Apropos.Script

import Test.Syd hiding (Context)
import Test.Syd.Hedgehog

import HelloDiscovery(standardNftMp)

import PlutusLedgerApi.V1 (
  BuiltinData (BuiltinData),
  Redeemer (..),
  Value (..),
  toData,
 )
import PlutusLedgerApi.V1.Scripts (Datum (..))
import PlutusLedgerApi.V2 (ScriptContext,TxOutRef,Address)

import Gen(txOutRef, address,value,maybeOf,datum)
import Control.Monad (forM_)

data NFTModel = NFTModel
  { param :: TxOutRef
  , inputs :: [(TxOutRef,Address,Value,Maybe Datum)]
  }
  deriving stock (Show)

data NFTProp
  = HasParam
  deriving stock (Show, Eq, Ord, Enum, Bounded, Generic)
  deriving anyclass (Enumerable, Hashable)

instance LogicalModel NFTProp where
  logic = Yes

instance HasLogicalModel NFTProp NFTModel where
  satisfiesProperty HasParam (NFTModel{..}) = param `elem` [ ref | (ref,_,_,_) <- inputs]

instance HasPermutationGenerator NFTProp NFTModel where
  sources =
    [ Source
        { sourceName = "Yes"
        , covers = Yes
        , gen =
            NFTModel
              <$> txOutRef
              <*> list (linear 0 64) ((,,,) <$> txOutRef <*> address <*> value <*> maybeOf datum)
        }
    ]
  generators =
    [ Morphism
        { name = "Add param"
        , match = Not $ Var HasParam
        , contract = add HasParam
        , morphism = \hm@NFTModel {..} -> do
          newIn <- (param,,,) <$> address <*> value <*> maybeOf datum
          pure hm {inputs = newIn :inputs}
        }
    ]

instance HasParameterisedGenerator NFTProp NFTModel where
  parameterisedGenerator = buildGen

mkCtx :: NFTModel -> ScriptContext
mkCtx NFTModel {..} =
  buildContext $ do
    withTxInfo $ do
      forM_ inputs $ \(ref,adr,val,md) -> addInput ref adr val md

instance ScriptModel NFTProp NFTModel where
  expect = Var HasParam
  script hm@NFTModel{param} =
    let redeemer = toData ()
     in applyMintingPolicy (mkCtx hm) (standardNftMp param) (Redeemer $ BuiltinData redeemer)

spec :: Spec
spec = do
  describe "simple nft tests" $ do
    mapM_
      fromHedgehogGroup
      [ runGeneratorTestsWhere @NFTProp "generators" Yes
      ]
    mapM_
      fromHedgehogGroup
      [ runScriptTestsWhere @NFTProp "validation" Yes
      ]
