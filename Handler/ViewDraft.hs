module Handler.ViewDraft where

import Import
import Common
import Handler.PrettyCard
import Data.Time
import qualified Data.Map as Map

getViewDraftR :: DraftId -> Handler Html
getViewDraftR draftId = do
    Just draft <- runDB $ get draftId
    Just participants <- sequence <$> (runDB $ mapM get $ draftParticipants draft)
    Just (Cube cubename _) <- runDB $ get $ draftCubeId draft
    picks <- getDraftPicks draftId
    muid <- maybeAuthId
    allowedCards <- getPickAllowedCards draftId draft
    let pickmap = Map.fromList $ map (\p -> (draftPickPickNumber p, p)) picks
        (lastRow, _) = pickNumToRC draft $ Map.size pickmap
        mnextdrafter = getNextDrafter draft picks
        isNextDrafter = case (mnextdrafter, muid) of
                            (Just nextdrafter, Just uid)
                                | uid == nextdrafter -> True
                            _ -> False
    catcards <- categorizeUnknownCardList allowedCards
    tz <- liftIO getCurrentTimeZone
    now <- liftIO getCurrentTime
    timestamp <- (elem "timestamp" . map fst . reqGetParams) <$> getRequest
    defaultLayout $ do
        setTitle "View Cube Draft"
        $(widgetFile "view-draft")

isLeftToRightRow :: Draft -> Int -> Bool
isLeftToRightRow _ r = even r

pickNumToRC :: Draft -> Int -> (Int, Int)
pickNumToRC draft i = (r, c)
 where
    n = length $ draftParticipants draft
    r = i `div` n
    dir | isLeftToRightRow draft r = id
        | otherwise                = (pred n -)
    c = dir (i `mod` n)

rcToPickNum :: Draft -> (Int, Int) -> Int
rcToPickNum draft (r, c) = r * n + dir c
 where
    n = length $ draftParticipants draft
    dir | isLeftToRightRow draft r = id
        | otherwise                = flip subtract (pred n)

prettyTimeDiff :: UTCTime -> UTCTime -> String
prettyTimeDiff t0 t1 = pref ++ concat
    [elide days "d ", elide hours "h ", show minutes ++ "m"]
 where
    t = diffUTCTime t0 t1
    elide n suff | n == 0    = ""
                 | otherwise = show n ++ suff
    posnegseconds = floor t :: Integer
    posneg = signum posnegseconds
    (days, dayremainder) = divMod (abs posnegseconds) (24*60*60)
    (hours, hourremainder) = divMod dayremainder (60*60)
    (minutes, _ ) = divMod hourremainder 60
    pref | posneg < 0 = "-"
         | otherwise = ""
