# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  # Admins carry the role-based `can :manage, :all` grant but may belong to no
  # Grouper groups (the admin role is the grant, not group membership — see
  # Ability). Keying the mount constraint purely on STAFF_EDIT_GROUP therefore
  # 404'd the jobs dashboard for admins (a Warden constraint miss surfaces as
  # "No route matches"), even though they outrank the staff-edit group. Admit
  # the admin role explicitly so both the intended staff-edit members and admins
  # reach it.
  authenticate :user, ->(u) { u.admin? || u.groups&.include?(Permissions::STAFF_EDIT_GROUP) } do
    mount MissionControl::Jobs::Engine, at: '/jobs'
  end

  mount Blacklight::Engine => '/catalog'
  root to: 'pages#home'
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  # The Blacklight :exportable concern (catalog#email/#sms) and the bookmarks
  # resource are intentionally NOT mounted: bookmarks is unused in Cerberus and
  # the email/sms tool links are stripped from the catalog config
  # (navbar/document_actions are empty), so these only ever existed as
  # anonymous, reachable POST send/abuse surfaces (authorization audit G5).
  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog'

  # Creating a child is nested under its destination; everything else stays flat
  # (`shallow: true`). The parent is a route SEGMENT rather than an optional
  # `?parent_id=`, so a create can't reach the controller without one — which is
  # what lets the :edit gate key on the destination and never be skipped. It also
  # keeps "where does this go?" out of the forms entirely: you say it by
  # navigating to the container you mean.
  # No unparented create for either container: a Collection must have a parent
  # (Atlas raises on a nil one), and a root Community is a seed-time concern, not
  # something the UI offers. Dropping the top-level new/create removes the
  # parentless route rather than patching the links that reached it.
  resources :communities, except: %i[new create destroy], shallow: true do
    resources :communities, only: %i[new create]
    resources :collections, only: %i[new create]
    member do
      post :tombstone
      # Ask DRS administrators to restrict this community. The form offers no
      # Private option — narrowing a community does not reach what is inside it
      # — so this is the only route. Edit-gated via authorize_resource_writes!.
      post :request_restriction
    end
  end
  resources :collections, except: %i[new create destroy], shallow: true do
    resources :collections, only: %i[new create]
    resources :works,       only: %i[new create]
    member do
      post :tombstone
      # Bulk metadata export (streamed ZIP) — dedicated Live controller, like sets.
      get 'export', to: 'collection_exports#show'
      # The collection's derivative-access default (Sentinel) — the per-tier policy
      # applied to Works created under it. Edit-gated (see authorize_resource_writes!).
      patch :sentinel
      # Ask DRS administrators to restrict this collection, for an editor whose
      # own narrowing was refused (NarrowingPolicy). Edit-gated.
      post :request_restriction
    end
  end
  resources :works, except: %i[index new create destroy] do
    member do
      get :downloads
      get :manifest
      get :metadata
      patch :metadata, action: :update_metadata
      # Add an arbitrary binary to an existing Work: GET renders the upload
      # form, POST stages the file and queues the attach (AddFileJob). Both are
      # edit-gated via authorize_resource_writes!'s extra_edit list.
      get :upload
      post :upload, action: :add_file
      post :tombstone
      # An editor-submitted request to withdraw or move the work — notifies the
      # DRS staff inbox (no direct mutation; staff fulfill it with the tombstone
      # / re-parent tools). Edit-gated via authorize_resource_writes!.
      post :request_change
    end
  end
  # People / profile pages. :id is the Person's NOID (opaque, public-safe — the
  # NUID is never in the URL). /people is a Blacklight browse of Person docs;
  # /people/:id is a curated profile over a gated depositor_ssi search;
  # /communities/:community_id/people is the community-scoped Faculty & Staff
  # browse (Person docs filtered by affiliated_community_ids_ssim).
  resources :people, only: %i[index show]
  get 'communities/:community_id/people', to: 'people#index', as: :community_people

  # Genre / category landing — a Featured-Content gateway (homepage) into a single
  # scholarly category. The genre rides the standard `f[genre_ssim][]` facet param
  # (so the active filter shows as a constraint chip); this surface just wraps the
  # gated Blacklight browse in a heading well, matching the People landing.
  get 'genres', to: 'genres#show', as: :genre

  # My DRS — the depositor's two-space home (workspace vs published). The deposit
  # fork's destinations, read back: their own collections on one side, their
  # community-published works on the other.
  get 'my_drs', to: 'my_drs#index', as: :my_drs

  # Self-service account switching for a person whose NUID holds several accounts
  # (their staff/student logins) — act as another of their accounts, or set the
  # preferred (default) one. Reached from the My DRS accounts panel.
  post 'accounts/switch', to: 'accounts#switch', as: :switch_account
  post 'accounts/prefer', to: 'accounts#prefer', as: :prefer_account

  # Personal-access token lifecycle behind the My DRS "Programmatic access"
  # section. Singular — a user only ever acts on their own token: create mints
  # (regenerate = revoke-then-mint), destroy revokes all outstanding tokens.
  resource :atlas_token, only: %i[create destroy]

  # The bare index is the "My Loaders" interstitial (user-menu entry);
  # everything else on a loader happens through its nested loads.
  resources :loaders, only: [:index], param: :slug do
    resources :loads, only: [:index, :show, :new, :create, :destroy] do
      member { patch :confirm }
      # JSON typeahead backing the XML/multipage destination picker — any
      # collection by title (NOID shown for visual confirmation).
      collection { get :collection_search }
    end
  end

  # User Inbox — in-app messaging. destroy is a per-recipient soft-dismiss,
  # not a row delete; recipients is the compose typeahead's JSON source.
  resources :messages, path: 'inbox', only: [:index, :show, :new, :create, :destroy] do
    collection { get :recipients }
  end

  # Download Queue — a per-session basket of individual files, downloaded later
  # as one streamed ZIP (reuses the bulk-download streaming tech). Anon-capable.
  # The zip stream lives on its own controller (ActionController::Live).
  get    'download_queue',          to: 'download_queue#show',      as: :download_queue
  post   'download_queue/items',    to: 'download_queue#create',    as: :download_queue_items
  delete 'download_queue/items',    to: 'download_queue#destroy',   as: :download_queue_item
  delete 'download_queue',          to: 'download_queue#destroy_all'
  get    'download_queue/archive',  to: 'queue_downloads#show', as: :download_queue_archive

  # Sets — personal curated sets over Atlas Compilations ("Set" is the only
  # word a user ever sees; "Compilation" is the model name on the wire).
  # Recipe mutations are member POST/DELETEs mirroring the atlas_rb binding;
  # `aside` is the set-aside / put-back pair.
  resources :sets do
    # picker: the lazy-loaded "Add to set…" menu body (Work/Collection show
    # pages). recipients: typeahead JSON for the Sharing tab's edit_users picker.
    collection do
      get :picker
      get :recipients
    end
    member do
      get    'download',                   to: 'set_downloads#show',     as: :download
      get    'export',                     to: 'set_exports#show',       as: :export
      get    'works_count',                to: 'sets#works_count',       as: :works_count
      post   'collections',                to: 'sets#add_collection',    as: :add_collection
      delete 'collections/:collection_id', to: 'sets#remove_collection', as: :remove_collection
      post   'works',                      to: 'sets#add_work',          as: :add_work
      delete 'works/:work_id',             to: 'sets#remove_work',       as: :remove_work
      post   'aside',                      to: 'sets#set_aside',         as: :set_aside
      delete 'aside/:work_id',             to: 'sets#put_back',          as: :put_back
      # The bulk actions. `sentinel` authors the Set's derivative-access policy
      # (the same verb the Collection tab uses); the two POSTs enqueue a sweep
      # over the Works the Set denotes. Both sweeps are operator-only — see
      # SetsController#require_bulk_operator.
      patch  'sentinel',                   to: 'sets#sentinel',          as: :sentinel
      post   'apply_sentinel',             to: 'sets#apply_sentinel',    as: :apply_sentinel
      post   'privatize',                  to: 'sets#privatize',         as: :privatize
    end
  end

  namespace :admin do
    root to: 'dashboard#index'
    # Destroy is refused for a loader that has run — see LoadersController.
    resources :loaders, only: [:index, :new, :create, :edit, :update, :destroy], param: :slug

    # Group names — the cosmetic display name for a Grouper group (raw → pretty),
    # consulted by ApplicationController#pretty_group wherever a group surfaces.
    resources :groups, only: [:index, :new, :create, :edit, :update, :destroy]

    # Usage analytics — repository-wide impression rollups (views/downloads),
    # with CSV/Excel export of the top-N tables (the quarterly-report artifact).
    get 'impressions',        to: 'impressions#index', as: :impressions
    get 'impressions/export', to: 'impressions#export', as: :impressions_export

    # Re-parent / Move — a self-contained finder: index (find the node) →
    # choose_parent (pick its new parent) → confirm (preview) → move (perform).
    get  'reparent',               to: 'reparent#index'
    get  'reparent/choose_parent', to: 'reparent#choose_parent', as: :reparent_choose_parent
    get  'reparent/confirm',       to: 'reparent#confirm',       as: :reparent_confirm
    post 'reparent/move',          to: 'reparent#move',          as: :reparent_move

    # Linked members — find a Work, then add/remove the Collections it is
    # surfaced in (discovery placement only; never its structural home).
    get    'linked_members',        to: 'linked_members#index'
    get    'linked_members/manage', to: 'linked_members#manage',  as: :linked_members_manage
    post   'linked_members/add',    to: 'linked_members#add',     as: :linked_members_add
    delete 'linked_members/remove', to: 'linked_members#remove',  as: :linked_members_remove

    # Associated works — find a Work, then assert or retract the typed edges
    # between it and other Works (codebook / figure / transcription / …).
    # Admin-only because Atlas gates the write that way: the claim renders on
    # the target's page too. `remove` carries holder_id, because the edge lives
    # on whichever Work asserted it and either direction is retractable here.
    get    'associations',        to: 'associations#index'
    get    'associations/manage', to: 'associations#manage',  as: :associations_manage
    post   'associations/add',    to: 'associations#add',     as: :associations_add
    delete 'associations/remove', to: 'associations#remove',  as: :associations_remove

    # People — the curatorial Person registry: create a Person by NUID, edit the
    # authoritative display_name / title / bio / orcid, and manage community
    # affiliations (the edges that drive the Faculty & Staff browse). Keyed by
    # NOID (the NUID is staff-facing and stays out of URLs).
    resources :people, only: %i[index new create edit update], param: :noid do
      member do
        post   'affiliations', to: 'people#add_affiliation', as: :add_affiliation
        delete 'affiliations/:community_id', to: 'people#remove_affiliation', as: :remove_affiliation
      end
    end

    # Deposits needing attention — the two ways a deposit gets stuck, on one
    # surface: `?state=unconfirmed` (nobody confirmed the metadata page) and
    # `?state=incomplete` (an enrichment job gave up). Read-only; every repair it
    # points at is gated on its own surface.
    get 'deposit_triage', to: 'deposit_triage#index', as: :deposit_triage

    # The ledger — `?tab=requests` (what depositors asked staff to do) and
    # `?tab=activity` (what the repository did). Two tabs on one surface, like
    # deposit triage, because they are read together; both are a filter on
    # AdminNotice#kind. Read-only: every remedy a row points at already exists
    # elsewhere and is gated there.
    get 'ledger', to: 'ledger#index'

    # The tombstone registry — every tombstoned Work / Collection / Community,
    # with the two ways out of a withdrawal: Restore reverses the show-page
    # tombstone, and DELETE purges the item for good (both via atlas_rb's
    # operator-only Admin namespace). :id is the resource NOID; the `type` body
    # param selects the right Admin class. The two verbs are gated differently
    # in the controller, matching Atlas: restore reaches the devolved-admin
    # tier, destroy is :admin only.
    resources :tombstones, only: %i[index destroy] do
      member { post :restore }
    end

    # Impersonation — a hub action surface (GET) hosting the start form, then
    # begin acting-as (write) or view-as (read-only) for a target NUID; the
    # DELETE (reusing admin_impersonation_path) ends whichever mode is active.
    get    'impersonation/recipients', to: 'impersonations#recipients', as: :impersonation_recipients
    get    'impersonation', to: 'impersonations#new',              as: :impersonation
    post   'act_as',        to: 'impersonations#create_acting_as', as: :act_as
    post   'view_as',       to: 'impersonations#create_view_as',   as: :view_as
    delete 'impersonation', to: 'impersonations#destroy'

    # Replace a file — find a Work, then non-destructively replace any of its
    # Blobs (Blob.update appends a new OCFL version, NOID preserved), view each
    # Blob's version history, and revert to a prior version. File-version content
    # streaming lives in its own Live controller (file_versions#content).
    get  'files',          to: 'files#index'
    get  'files/manage',   to: 'files#manage',   as: :files_manage
    post 'files/replace',  to: 'files#replace',  as: :files_replace
    post 'files/rollback', to: 'files#rollback', as: :files_rollback
    get  'files/:id/versions/:version_id/content', to: 'file_versions#content',
                                                   as: :file_version_content

    # Reindex — rebuild a resource's Solr doc from Atlas's authoritative store,
    # the in-app counterpart to lib/tasks/reindex.rake. A Work is one call and
    # answers inline; a Set walks its recipe in a job and reports to the inbox.
    # Mounted here rather than on the show-page controllers because the Atlas
    # endpoint behind them is system-gated and applies no per-user check.
    post 'reindex/work/:noid', to: 'reindex#work', as: :reindex_work
    post 'reindex/set/:noid',  to: 'reindex#set',  as: :reindex_set
  end

  get '/downloads/:id', to: 'downloads#show', as: :download
  # Gated image-derivative delivery (small/medium/large). Authorizes the tier,
  # then redirects to a short-lived signed URL on the gated Cantaloupe host.
  get '/works/:work_id/derivatives/:use', to: 'derivative_downloads#show', as: :derivative_download
  # Inline, Range-capable A/V byte serving for the in-page player (download twin).
  get '/media/:id',     to: 'media#show',     as: :media

  # history — deep diff views reached from the audit-log "View" button.
  # Type-agnostic (the data layer hits Atlas's /resources/:id/* endpoints), so
  # a single flat route serves Work / Collection / Community alike.
  get '/resources/:id/rights_history', to: 'histories#rights', as: :rights_history
  get '/resources/:id/mods_history',   to: 'histories#mods',   as: :mods_history

  # xml
  get '/xml/editor/:id' => 'xml#editor', as: 'xml_editor'
  put '/xml/validate' => 'xml#validate'
  put '/xml/update' => 'xml#update'

  # atlas
  #
  # The NUID sign-in shim stands in for SSO, which only exists in production, so
  # dev and staging need it to sign in at all. It authenticates on a submitted
  # NUID alone — no secret — and process_find_or_create additionally accepts a
  # `groups` list, so it can mint an account carrying the repository admin group.
  # That is acceptable where SSO is absent and unacceptable beside it, so the
  # routes do not exist in production rather than relying on nobody finding them.
  #
  # ApplicationHelper#nuid_sign_in_available? mirrors this condition for the views
  # that link here; the two have to move together.
  unless Rails.env.production?
    get '/atlas/login' => 'atlas#login'
    post '/atlas/process_login' => 'atlas#process_login'
    get '/atlas/find_or_create' => 'atlas#find_or_create'
    post '/atlas/process_find_or_create' => 'atlas#process_find_or_create'
  end

  # Not gated: the user menu links here for everyone, and it only renders the
  # signed-in user's own record.
  get '/atlas/user' => 'atlas#user'

  # error pages — also targeted by config.exceptions_app
  match '/403', to: 'errors#forbidden',             via: :all
  match '/404', to: 'errors#not_found',             via: :all
  match '/410', to: 'errors#gone',                  via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
