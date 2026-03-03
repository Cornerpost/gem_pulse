GemPulse::Engine.routes.draw do
  root to: "dashboard#index"

  # /gem_pulse/gems        → GemsController#index  (full gem table)
  # /gem_pulse/gems/rails  → GemsController#show   (per-gem detail)
  resources :gems, only: [ :index, :show ], param: :name
end
