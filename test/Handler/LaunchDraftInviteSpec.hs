module Handler.LaunchDraftInviteSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do

    describe "postLaunchDraftInviteR" $ do
        it "starts the draft" $ do
            postCube testLargeCubeName testLargeCube
            Just (Entity cid _) <- runDB $ selectFirst ([] :: [Filter Cube]) []
            postDraftInvite cid
            Just (Entity _ inv) <- runDB $ selectFirst ([] :: [Filter DraftInvite]) []
            post $ JoinDraftInviteR $ inv ^. draftInviteHash
            post $ LaunchDraftInviteR $ inv ^. draftInviteHash
            statusIs 303
