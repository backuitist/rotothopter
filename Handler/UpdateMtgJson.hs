module Handler.UpdateMtgJson where

import Import
import Data.Aeson
import qualified Data.Map as Map
import qualified Data.Set as Set

getUpdateMtgJsonR :: Handler Html
getUpdateMtgJsonR = do
    defaultLayout
        [whamlet|
            <form method=post action=@{UpdateMtgJsonR}>
                <button .btn btn-primary type="submit">
                    Reload mtgjson.com data
        |]

-- Possible values: normal, split, flip, double-faced, token, plane, scheme, phenomenon, leveler, vanguard
data Layout = Split
            | Flip
            | DoubleFaced
            | MehLayout
 deriving Show

data CardInfo = CardInfo { ciname :: Text, cicolors :: [Text], citypes :: [Text], layout :: Layout, names :: Maybe [Text] }
 deriving Show

instance FromJSON CardInfo where
    parseJSON (Object v) = CardInfo
                            <$> v .: "name"
                            <*> v .:? "colors" .!= []
                            <*> v .:? "types" .!= []
                            <*> v .: "layout"
                            <*> v .:? "names" .!= Nothing
    parseJSON _ = mzero

instance FromJSON Layout where
    parseJSON (String s) = return $
                            case s of
                                "split" -> Split
                                "flip" -> Flip
                                "double-faced" -> DoubleFaced
                                _ -> MehLayout
    parseJSON _ = mzero

uniq :: Ord a => [a] -> [a]
uniq xs = Set.toList . Set.fromList $ xs

-- | Assume all CardInfo are part of the same split card
combineCardInfo :: [CardInfo] -> CardInfo
combineCardInfo xs@(CardInfo {layout = Split, names = Just ns}:_) = CardInfo
    { ciname = name
    , cicolors = uniq $ concatMap cicolors xs
    , citypes = uniq $ concatMap citypes xs
    , layout = Split
    , names = Just ns
    }
 where
    name = intercalate " // " ns
combineCardInfo xs@(CardInfo {names = Just (n:_)}:_) = prime
 where (prime:_) = [x | x <- xs, ciname x == n]
combineCardInfo xs = error $ "called with bad argument: " ++ show xs

massage :: Map Text CardInfo -> [Card]
massage cs' = [Card (ciname ci) (cicolors ci) (citypes ci)
                | ci <- singlenames ++ massagedMultinames]
 where
    cs = Map.elems cs'
    singlenames = [c | c@(CardInfo {names = Nothing}) <- cs]
    multinames = Map.elems $ Map.fromListWith (++)
                    [(ns, [c]) | c@(CardInfo {names = Just ns}) <- cs ]
    massagedMultinames = map combineCardInfo multinames
-- map (\(n, i) -> Card n (cicolors i) (citypes i)) . Map.toList

postUpdateMtgJsonR :: Handler Html
postUpdateMtgJsonR = do
    req <- parseUrl url
    js <- responseBody <$> httpLbs req
    case massage <$> eitherDecode js of
        Left err -> fail err
        Right cs -> do
            runDB $ do
                deleteWhere ([] :: [Filter Card])
                mapM_ (\c -> insert c >> return ()) cs
            defaultLayout [whamlet|
                <p>Successfully loaded #{length cs} cards
            |]
 where
    url = "http://mtgjson.com/json/AllCards.json"
