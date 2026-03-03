module GemPulse
  module ApplicationHelper
    def gp_sort_link(column, label)
      current_sort = params[:sort] == column
      direction = current_sort && params[:direction] != "desc" ? "desc" : "asc"
      indicator = current_sort ? (params[:direction] == "desc" ? " &#9660;" : " &#9650;") : ""
      link_to "#{label}#{indicator}".html_safe,
        gems_path(sort: column, direction: direction, status: params[:status]),
        class: "gp-sort-link"
    end
  end
end
