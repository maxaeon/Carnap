module Handler.Info where

import Import
import Text.Shakespeare.Text
--import Text.Hamlet

getInfoR :: Handler Html
getInfoR = do
    defaultLayout $ do
        addScript $ StaticR ghcjs_rts_js
        addScript $ StaticR ghcjs_allactions_lib_js
        addScript $ StaticR ghcjs_allactions_out_js
        setTitle "Carnap - About"
        $(widgetFile "infopage")
        addStylesheet $ StaticR css_tree_css
        addStylesheet $ StaticR css_exercises_css
        -- TODO : split out the stuff specifically relating to exercises
        addScript $ StaticR ghcjs_allactions_runmain_js

-- TODO remove submit option on these.
proofcheck :: Int -> Text -> Text -> Text -> HtmlUrl url
proofcheck n cls goal proof = 
        [hamlet|
        <div class="exercise">
            <span>example #{show n}
            <div class="#{cls}">
                <div.goal>#{goal}
                <textarea>#{proof}
                <div.output>
        |]

-- XXX function that strips text of indentation and line-numbers.
ded1 = [st|
Show: P
   P:PR
:DD 2
|]

ded2 = [st|
  (P->Q)->P:AS
     -P:AS
        P:AS
          Q:AS
          P:R 3
          -P:R 2
        Q:-E 4-6
     P->Q:CI 3-7
     P:CE 8 1
     -P:R 2
  P:-E 2-10
((P->Q)->P)->P:CI 1-11
|]