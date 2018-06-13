class EtdsController < ApplicationController
  def years
    # Need to do public/embargo filter
    row_count = ActiveFedora::SolrService.count("drs_category_ssim:\"Theses and Dissertations\"")
    results = ActiveFedora::SolrService.query("drs_category_ssim:\"Theses and Dissertations\"", :fl => "key_date_ssi", :fq => "read_access_group_ssim:\"public\" AND -(in_progress_tesim:true OR incomplete_tesim:true) AND -(embargo_release_date_dtsi:* OR -embargo_release_date_dtsi:[* TO NOW])", :rows => row_count)
    results = results.map{ |hsh| hsh["key_date_ssi"] }
    results = results.uniq
    results.reject! { |x| x.blank? }
    results.map!{ |d| d.split("/").first }

    @years = results.uniq.sort_by(&:to_i)
  end
end
