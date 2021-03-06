{-|

Authority ring instantiation and access token creation.

--}

module Authority (
  -- ** Creation
  authorityDir,
  authorityDirs,

  -- ** Token
  Token,
  createAccessToken,
  signWithToken,
  verifyMsg,

  -- ** Token
  testToken,
) where

import Protolude

import System.FilePath
import qualified Data.Map as Map
import qualified Data.ByteArray as BS
import qualified Data.ByteString.Lazy as BS

import Data.Aeson ((.=))
import qualified Data.Aeson as A
import qualified Data.Aeson.Encode.Pretty as A

import qualified Key
import qualified Time
import qualified Utils
import qualified Account
import qualified Address
import qualified Encoding

-------------------------------------------------------------------------------
-- Creation
-------------------------------------------------------------------------------

-- | Create account data for
authorityDir :: FilePath -> IO ()
authorityDir dbpath = do
  let meta = Account.Metadata $ Map.fromList [("validator", "true")]
  (account, acctKeys) <- Account.newAccount "GMT" meta

  Utils.putGreen "Writing account"
  putStrLn (Address.rawAddr (Account.address account))

  Account.createAccountDir dbpath
  Account.writeKeys dbpath acctKeys
  Account.writeAccount dbpath account
  pure ()

-- | Create validator accounts for genesis block
authorityDirs :: FilePath -> Int -> IO ()
authorityDirs prefix n = mapM_ authorityDir validators
  where
    validators = [prefix <> show i | i <- [0..n]]

-------------------------------------------------------------------------------
-- Access Token
-------------------------------------------------------------------------------

newtype Token = Token ByteString
  deriving (Eq, Ord, Show)

createAccessToken :: ByteString -> IO (Time.Timestamp, Token)
createAccessToken secret = do
  ts <- Time.now
  let sig = Encoding.base64 (Key.hmacSha256 secret (show ts))
  return (ts, Token sig)

signWithToken :: Token -> ByteString -> ByteString
signWithToken (Token token) msg = Encoding.base64 (Key.hmacSha256 token msg)

verifyMsg
  :: Token      -- ^ Access token
  -> ByteString -- ^ Message
  -> ByteString -- ^ Digest
  -> Bool
verifyMsg tok msg digest =
  -- IMPORTANT: use constant time equality, not (==)
  BS.constEq (signWithToken tok msg) digest

writeToken :: (Time.Timestamp, Token) -> IO ()
writeToken (ts, Token tok) = do
  let json = A.object [ "timestamp" .= ts, "token".= (toS tok :: Text) ]
  BS.writeFile "token" (A.encodePretty json)

-------------------------------------------------------------------------------
-- Testing
-------------------------------------------------------------------------------

testToken :: IO ()
testToken = do
  (ts, tok) <- createAccessToken "hunter2"
  writeToken (ts, tok)
  let msg = "Adjoint Inc"
  let digest = signWithToken tok "Adjoint Inc"
  print (verifyMsg tok msg digest)
