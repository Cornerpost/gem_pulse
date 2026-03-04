module GemPulse
  module ApplicationHelper
    def gp_sort_link(column, label)
      current_sort = params[:sort] == column
      direction = current_sort && params[:direction] != "desc" ? "desc" : "asc"
      indicator = current_sort ? (params[:direction] == "desc" ? " &#9660;" : " &#9650;") : ""
      link_to "#{label}#{indicator}".html_safe,
        gems_path(sort: column, direction: direction, status: params[:status], category: params[:category]),
        class: "gp-sort-link"
    end

    def gp_tip_sort_link(column, label, tip)
      content_tag(:span, class: "gp-tip", data: { tip: tip }) do
        gp_sort_link(column, label)
      end
    end

    def gp_score_class(score)
      return "gp-score-unknown" if score.nil?
      if score >= 70
        "gp-score-high"
      elsif score >= 40
        "gp-score-mid"
      else
        "gp-score-low"
      end
    end

    def gp_version_class(locked, latest)
      return "gp-version-neutral" if latest.nil? || locked.nil?
      locked == latest ? "gp-version-current" : "gp-version-outdated"
    end
  end
end
