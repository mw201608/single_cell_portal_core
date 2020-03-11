require 'api_test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.find_by(email: 'testing.user.2@gmail.com')
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
  end

  test 'should get all search facets' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    facet_count = SearchFacet.count
    execute_http_request(:get, api_v1_search_facets_path)
    assert_response :success
    assert json.size == facet_count, "Did not find correct number of search facets, expected #{facet_count} but found #{json.size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should search facet filters' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    @search_facet = SearchFacet.first
    filter = @search_facet.filters.first
    valid_query = filter[:name]
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: valid_query))
    assert_response :success
    assert_equal json['query'], valid_query, "Did not search on correct value; expected #{valid_query} but found #{json['query']}"
    assert_equal json['filters'].first, filter, "Did not find expected filter of #{filter} in response: #{json['filters']}"
    invalid_query = 'does not exist'
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: invalid_query))
    assert_response :success
    assert_equal json['query'], invalid_query, "Did not search on correct value; expected #{invalid_query} but found #{json['query']}"
    assert_equal json['filters'].size, 0, "Should have found no filters; expected 0 but found #{json['filters'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end

  test 'should return viewable studies on empty search' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    execute_http_request(:get, api_v1_search_path(type: 'study'))
    assert_response :success
    expected_studies = Study.viewable(@user).pluck(:accession).sort
    found_studies = json['matching_accessions'].sort
    assert_equal expected_studies, found_studies, "Did not return correct studies; expected #{expected_studies} but found #{found_studies}"

    sign_out @user
    execute_http_request(:get, api_v1_search_path(type: 'study'))
    assert_response :success
    expected_studies = Study.viewable(nil).pluck(:accession).sort
    public_studies = json['matching_accessions'].sort
    assert_equal expected_studies, public_studies, "Did not return correct studies; expected #{expected_studies} but found #{public_studies}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return search results using facets' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    facets = SearchFacet.where(data_type: 'string')
    # format facet query string; this will be done by the search UI in production
    facet_queries = []
    facets.each do |facet|
      if facet.filters.any?
        facet_queries << [facet.identifier, facet.filters.map {|f| f[:id]}.join(',')]
      end
    end
    facet_query = facet_queries.map {|query| query.join(':')}.join('+')
    execute_http_request(:get, api_v1_search_path(type: 'study', facets: facet_query))
    assert_response :success
    expected_accessions = [study.accession]
    matching_accessions = json['matching_accessions']
    assert_equal expected_accessions, matching_accessions,
                 "Did not return correct array of matching accessions, expected #{expected_accessions} but found #{matching_accessions}"
    study_count = json['studies'].size
    assert_equal study_count, 1, "Did not find correct number of studies, expected 1 but found #{study_count}"
    result_accession = json['studies'].first['accession']
    assert_equal result_accession, study.accession, "Did not find correct study; expected #{study.accession} but found #{result_accession}"
    matched_facets = json['studies'].first['facet_matches'].keys.sort
    matched_facets.delete_if {|facet| facet == 'facet_search_weight'} # remove search weight as it is not relevant
    source_facets = facets.map(&:identifier).sort
    assert_equal source_facets, matched_facets, "Did not match on correct facets; expected #{source_facets} but found #{matched_facets}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return search results using numeric facets' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    facet = SearchFacet.find_by(identifier: 'organism_age')

    # loop through 3 different units (days, months, years) to run a numeric-based facet query with conversion
    # days should return nothing, but months and years should match the testing study
    %w(days months years).each do |unit|
      facet_query = "#{facet.identifier}:#{facet.min + 1},#{facet.max - 1},#{unit}"
      execute_http_request(:get, api_v1_search_path(type: 'study', facets: facet_query))
      assert_response :success
      expected_accessions = unit == 'days' ? [] : [study.accession]
      matching_accessions = json['matching_accessions']
      assert_equal expected_accessions, matching_accessions,
                   "Facet query: #{facet_query} returned incorrect matches; expected #{expected_accessions} but found #{matching_accessions}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return search results using keywords' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_count = Study.count
    execute_http_request(:get, api_v1_search_path(type: 'study', terms: @random_seed))
    assert_response :success
    expected_accessions = Study.pluck(:accession)
    matching_accessions = json['matching_accessions'].sort # need to sort results since they are returned in weighted order
    assert_equal expected_accessions, matching_accessions,
                 "Did not return correct array of matching accessions, expected #{expected_accessions} but found #{matching_accessions}"

    result_count = json['studies'].size
    assert_equal study_count, result_count, "Did not find correct number of studies, expected #{study_count} but found #{result_count}"
    assert_equal @random_seed, json['studies'].first['term_matches']

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # should generate an auth code for a given user
  test 'should generate auth code' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    execute_http_request(:post, api_v1_create_auth_code_path)
    assert_response :success
    assert_not_nil json['auth_code'], "Did not generate auth code; missing 'totat' field: #{json}"
    auth_code = json['auth_code']
    @user.reload
    assert_equal auth_code, @user.totat

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # should generate a config text file to pass to curl for bulk download
  test 'should generate curl config for bulk download' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    file_types = %w(Expression Metadata).join(',')
    execute_http_request(:post, api_v1_create_auth_code_path)
    assert_response :success
    auth_code = json['auth_code']

    files = study.study_files.by_type(['Expression Matrix', 'Metadata'])
    execute_http_request(:get, api_v1_search_bulk_download_path(
        auth_code: auth_code, accessions: study.accession, file_types: file_types)
    )
    assert_response :success

    config_file = json
    files.each do |file|
      filename = file.upload_file_name
      assert config_file.include?(filename), "Did not find URL for filename: #{filename}"
      output_path = file.bulk_download_pathname
      assert config_file.include?(output_path), "Did not correctly set output path for #{filename} to #{output_path}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return preview of bulk download files and total bytes' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    file_types = %w(Expression Metadata)
    execute_http_request(:get, api_v1_search_bulk_download_size_path(
        accessions: study.accession, file_types: file_types.join(','))
    )
    assert_response :success

    expected_response = {
        Metadata: {
            total_files: 1,
            total_bytes: study.metadata_file.upload_file_size
        },
        Expression: {
            total_files: 1,
            total_bytes: study.expression_matrix_files.first.upload_file_size
        }
    }.with_indifferent_access

    assert_equal expected_response, json.with_indifferent_access,
                 "Did not correctly return bulk download sizes, expected #{expected_response} but found #{json}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should filter search results by branding group' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # add study to branding group and search - should get 1 result
    study = Study.find_by(name: "Test Study #{@random_seed}")
    branding_group = BrandingGroup.first
    study.update(branding_group_id: branding_group.id)

    query_parameters = {type: 'study', terms: @random_seed, scpbr: branding_group.name_as_id}
    execute_http_request(:get, api_v1_search_path(query_parameters))
    assert_response :success
    result_count = json['studies'].size
    assert_equal 1, result_count, "Did not find correct number of studies, expected 1 but found #{result_count}"

    # remove study from group and search again - should get 0 results
    study.update(branding_group_id: nil)
    execute_http_request(:get, api_v1_search_path(query_parameters))
    assert_response :success
    assert_empty json['studies'], "Did not find correct number of studies, expected 0 but found #{json['studies'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end