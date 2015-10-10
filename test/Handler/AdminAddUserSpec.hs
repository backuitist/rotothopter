module Handler.AdminAddUserSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    describe "getAdminAddUserR" $ do
        checkRequiresAdmin AdminAddUserR

    describe "postAdminAddUserR" $ do
        it "allows admin to add a user" $ do
            authenticateAdmin
            get AdminAddUserR
            statusIs 200
            request $ do
                addToken
                byLabel "Email" x
                byLabel "Name" xname
                setMethod "POST"
                setUrl AdminAddUserR
            statusIs 303
            Just (Entity _ usr) <- runDB $ getBy $ UniqueUser x
            assertEqual "userIdent" x (userIdent usr)
            assertEqual "userDisplayName" (Just xname) (userDisplayName usr)
 where
    (x, xname) = ("x@test.com", "Xavier")
