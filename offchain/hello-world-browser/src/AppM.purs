module HelloWorld.AppM where

import Contract.Prelude

import Contract.Config (NetworkId(..), WalletSpec(..), mainnetConfig, mainnetNamiConfig, testnetEternlConfig, testnetNamiConfig)
import Contract.Monad (Contract, liftContractM, runContract)
import Contract.Transaction (TransactionOutput(..))
import Contract.Utxos (getUtxo, getWalletBalance)
import Contract.Value (Value, getLovelace, valueToCoin)
import Control.Alt ((<|>))
import Control.Parallel (parallel, sequential)
import Data.BigInt (BigInt, fromInt, toNumber)
import Data.String (Pattern(..), contains)
import Data.Time.Duration (Milliseconds(..), Seconds(..), fromDuration)
import Effect.Aff (Aff, attempt, delay, message, throwError, try)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect)
import Effect.Exception (error)
import Halogen as H
import Halogen.Store.Monad (class MonadStore, StoreT, getStore, runStoreT, updateStore)
import HelloWorld.Api (datumLookup, increment, initialize, redeem, resumeCounter)
import HelloWorld.Capability.CardanoApi (class CardanoApi)
import HelloWorld.Capability.HelloWorldApi (class HelloWorldApi, FundsLocked(..), HelloWorldIncrement(..))
import HelloWorld.CardanoApi as CardanoApi
import HelloWorld.Error (HelloWorldBrowserError(..))
import HelloWorld.Store as S
import HelloWorld.Types (ContractConfig, HelloWorldWallet(..))
import Safe.Coerce (coerce)

newtype AppM a = AppM (StoreT S.Action S.Store Aff a)

runAppM :: forall q i o. S.Store -> H.Component q i o AppM -> Aff (H.Component q i o Aff)
runAppM store = runStoreT store S.reduce <<< coerce

derive newtype instance functorAppM :: Functor AppM
derive newtype instance applyAppM :: Apply AppM
derive newtype instance applicativeAppM :: Applicative AppM
derive newtype instance bindAppM :: Bind AppM
derive newtype instance monadAppM :: Monad AppM
derive newtype instance monadEffectAppM :: MonadEffect AppM
derive newtype instance monadAffAppM :: MonadAff AppM
derive newtype instance monadStoreAppM :: MonadStore S.Action S.Store AppM

timeoutMilliSeconds :: Milliseconds
timeoutMilliSeconds = Milliseconds 240_000_000.0

timeoutErrorMessage :: String
timeoutErrorMessage = "timeout"

timeout :: forall (a :: Type). Milliseconds -> Aff a -> Aff a
timeout ms ma = do
  r <- sequential (parallel (attempt mkTimeout) <|> parallel (attempt ma))
  either throwError pure r
  where
  mkTimeout = do
    delay ms
    throwError $ error timeoutErrorMessage

valueToFundsLocked :: Value -> FundsLocked
valueToFundsLocked val = (FundsLocked (toNumber ((getLovelace $ valueToCoin val) / fromInt 1_000_000)))

getWalletBalance' :: forall (r :: Row Type). Contract r BigInt
getWalletBalance' = do
  balance <- getWalletBalance >>= liftContractM "Get wallet balance failed"
  pure $ getLovelace $ valueToCoin balance

ensureContractConfig :: forall a. (ContractConfig -> AppM (Either HelloWorldBrowserError a)) -> AppM (Either HelloWorldBrowserError a)
ensureContractConfig fa = do
  { contractConfig } <- getStore
  case contractConfig of
    Nothing -> pure $ Left (OtherError $ error "Contract config not found")
    Just config -> fa config

ensureNetworkNotChanged :: forall a. ContractConfig -> AppM (Either HelloWorldBrowserError a) -> AppM (Either HelloWorldBrowserError a)
ensureNetworkNotChanged contractConfig fa =
  case contractConfig.walletSpec of
    Just ConnectToNami -> go "nami"
    Just ConnectToEternl -> go "eternl"
    _ -> fa
  where
  go wallet = do
    result <- liftAff $ try (CardanoApi.enable wallet)
    case result of
      Right conn -> do
        networkId <- liftAff $ CardanoApi.getNetworkId conn
        if (networkId == contractConfig.networkId) then
          fa
        else
          pure $ Left NetworkChanged
      Left _ -> pure $ Left FailedToEnable

instance cardanoApiAppM :: CardanoApi AppM where
  enable = case _ of
    Nami -> go "nami" mainnetNamiConfig { logLevel = Warn } testnetNamiConfig { logLevel = Warn }
    Eternl -> go "eternl" (mainnetConfig { walletSpec = Just ConnectToEternl }) { logLevel = Warn } testnetEternlConfig { logLevel = Warn }
    where
    go wallet mainnetConfig testnetConfig = do
      result <- liftAff $ try (CardanoApi.enable wallet)
      case result of
        Right conn -> do
          result' <- liftAff $ try (CardanoApi.getNetworkId conn)
          case result' of
            Left _ -> pure $ Left FailedToGetNetworkId
            Right networkId -> do
              let
                contractConfig' = case networkId of
                  MainnetId -> mainnetConfig
                  TestnetId -> testnetConfig
              updateStore $ S.SetContractConfig contractConfig'
              pure $ Right unit
        Left _ -> pure $ Left FailedToEnable

instance helloWorldApiAppM :: HelloWorldApi AppM where
  lock (HelloWorldIncrement param) initialValue =
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ runContract contractConfig $ do
          lastOutput <- initialize param initialValue
          -- TODO we should probably add an api function thing to get the lovelace at the output
          TransactionOutput utxo <- getUtxo lastOutput >>= liftContractM "couldn't find utxo"
          pure $ (lastOutput /\ (valueToFundsLocked $ utxo.amount))
        case result of
          Left err ->
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right (lastOutput /\ fundsLocked) ->
            pure $ Right (lastOutput /\ fundsLocked)

  increment (HelloWorldIncrement param) lastOutput =
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ runContract contractConfig $ do
          increment param lastOutput
        case result of
          Left err ->
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right lastOutput' ->
            pure $ Right lastOutput'

  redeem (HelloWorldIncrement param) lastOutput =
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ runContract contractConfig $ do
          balanceBeforeRedeem <- getWalletBalance'
          redeem param lastOutput
          pure balanceBeforeRedeem
        case result of
          Left err ->
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right balanceBeforeRedeem ->
            pure $ Right balanceBeforeRedeem

  unlock balanceBeforeRedeem = do
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ ((void <<< _) <<< runContract) contractConfig $ do
          go balanceBeforeRedeem
        case result of
          Left err ->
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right _ -> do
            pure $ Right unit
    where
    go balanceBeforeRedeem' = do
      balance <- getWalletBalance'

      if balance > balanceBeforeRedeem' then
        pure unit
      else do
        liftAff $ delay $ fromDuration (Seconds 5.0)
        go balanceBeforeRedeem'

  resume (HelloWorldIncrement param) =
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ runContract contractConfig $ do
          txIn <- resumeCounter param
          case txIn of
            Nothing -> pure Nothing
            Just txIn' -> do
              out <- getUtxo txIn' >>= liftContractM "no utxo?"
              pure $ Just $ txIn' /\ valueToFundsLocked (unwrap out).amount
        case result of
          Left err ->
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right Nothing ->
            pure $ Left $ OtherError $ error "no utxo to resume"
          Right (Just (newOutput /\ funds)) ->
            pure $ Right (newOutput /\ funds)

  getDatum lastOutput =
    ensureContractConfig $ \contractConfig -> do
      ensureNetworkNotChanged contractConfig do
        result <- liftAff $ try $ timeout timeoutMilliSeconds $ runContract contractConfig $ do
          datumLookup lastOutput
        case result of
          Left err ->
            -- TODO this block seems to be repeated several times it should really be a function
            if message err == timeoutErrorMessage then
              pure $ Left TimeoutError
            else if (contains (Pattern "InsufficientTxInputs") (message err)) then
              pure $ Left InsufficientFunds
            else
              pure $ Left (OtherError err)
          Right count -> do
            pure $ Right count