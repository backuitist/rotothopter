module App.Layout where

import App.NotFound as NotFound
import App.Picker as Picker
import App.LaunchDraft as LaunchDraft
import App.ViewDraft as ViewDraft
import App.Routes (Route(NotFoundR, PickerR, LaunchDraftR, ViewDraftR), None(..))
import DOM (DOM)
import Network.HTTP.Affjax (AJAX)
import Prelude (map, ($), (<$>), (==))
import Pux (EffModel, mapEffects, mapState, noEffects)
import Pux.Html (Html, div, h1, p, text)
import Signal.Channel (CHANNEL)

data Action
  = PageView (Route None)
  | Picker Picker.RankId Picker.Action
  | PickerLoaded Picker.RankId Picker.State
  | LaunchDraft LaunchDraft.InviteId LaunchDraft.Action
  | LaunchDraftLoaded LaunchDraft.InviteId LaunchDraft.State
  | ViewDraft ViewDraft.DraftId ViewDraft.Action
  | ViewDraftLoaded ViewDraft.DraftId ViewDraft.State

data Loading a = Loading | Loaded a

type State =
  { route :: Route Loading }

init :: State
init =
  { route: NotFoundR }

routeInit :: Route None -> EffModel (Route Loading) Action (ajax :: AJAX, dom :: DOM)
routeInit NotFoundR = noEffects NotFoundR
routeInit (PickerR n None) = {state: PickerR n Loading, effects: [PickerLoaded n <$> Picker.init n]}
routeInit (LaunchDraftR d None) = {state: LaunchDraftR d Loading, effects: [LaunchDraftLoaded d <$> LaunchDraft.init d]}
routeInit (ViewDraftR d None) = {state: ViewDraftR d Loading, effects: [ViewDraftLoaded d <$> ViewDraft.init d]}

update :: Action -> State -> EffModel State Action (ajax :: AJAX, dom :: DOM )
update (PageView route) state = mapState (\route' -> state { route = route' }) $ routeInit route
update (Picker rankId a) state = case state.route of
  PickerR rankId' (Loaded s) | rankId == rankId' ->
    mapEffects (Picker rankId)
    $ mapState (\s' -> state {route = PickerR rankId (Loaded s')})
    $ Picker.update rankId a s
  _ -> noEffects state
update (PickerLoaded rankId ps) state = noEffects case state.route of
  PickerR rankId' Loading | rankId == rankId' -> state {route = PickerR rankId (Loaded ps)}
  _ -> state
update (LaunchDraft draftId lda) state = noEffects case state.route of
  LaunchDraftR draftId' (Loaded lds) | draftId == draftId' -> state {route = LaunchDraftR draftId $ Loaded $ LaunchDraft.update lda lds}
  _ -> state
update (LaunchDraftLoaded draftId lds) state = noEffects case state.route of
  LaunchDraftR draftId' Loading | draftId == draftId' -> state {route = LaunchDraftR draftId (Loaded lds)}
  _ -> state
update (ViewDraft draftId vda) state = case state.route of
  ViewDraftR draftId' (Loaded vds) | draftId == draftId' ->
    mapEffects (ViewDraft draftId)
    $ mapState (\s' -> state {route = ViewDraftR draftId (Loaded s')})
    $ ViewDraft.update draftId vda vds
  _ -> noEffects state
update (ViewDraftLoaded draftId vds) state = noEffects case state.route of
  ViewDraftR draftId' Loading | draftId == draftId' -> state {route = ViewDraftR draftId (Loaded vds)}
  _ -> state

view :: State -> Html Action
view state =
  div
    []
    [ case state.route of
        PickerR rankId (Loaded pstate) -> Picker rankId <$> Picker.view rankId pstate
        PickerR _ Loading -> p [] [text "Loading..."]
        LaunchDraftR _ Loading -> p [] [text "Loading..."]
        LaunchDraftR draftId (Loaded dstate) -> LaunchDraft draftId <$> LaunchDraft.view draftId dstate
        ViewDraftR _ Loading -> p [] [text "Loading reserved picks..."]
        ViewDraftR draftId (Loaded dstate) -> ViewDraft draftId <$> ViewDraft.view draftId dstate
        NotFoundR -> NotFound.view state
    ]
