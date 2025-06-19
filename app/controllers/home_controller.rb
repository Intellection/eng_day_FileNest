class HomeController < ApplicationController
  skip_before_action :authorize_request, only: [ :index ]

  def index
    render file: Rails.root.join("public", "index.html")
  end
end
