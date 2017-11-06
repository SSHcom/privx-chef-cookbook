#
# Cookbook:: privx
# Library:: Privx::ApiClient
#
# Copyright:: 2017, SSH Communications Security, Inc, All Rights Reserved.


require 'net/http'
require 'json'

module PrivX
  class ApiClient
    def initialize(ext_secret, client_id, client_secret, api_base,
                   ca_file_name)
      @ext_secret = ext_secret
      @client_id = client_id
      @client_secret = client_secret
      @api_base = api_base
      @ca_file_name = ca_file_name
    end

    def get_http_client uri
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_file = @ca_file_name
      end

      return http
    end

    def authenticate
      uri = URI ("#{@api_base}/auth/api/v1/oauth/token")
      params = {
        "grant_type": "password",
        "username": @client_id,
        "password": @client_secret,
      }
      uri.query = URI.encode_www_form(params)

      http = self.get_http_client uri
      request = Net::HTTP::Post.new(uri,
        'Content-Type' => 'application/x-www-form-urlencoded')
      request.basic_auth "privx-external", @ext_secret

      response = http.request request
      if response.code != '200'
        raise "Client OAUTH authentication failed #{response.code} #{response.body}"
      end

      access_token_response = JSON.parse(response.body)
      @access_token = access_token_response['access_token']
    end

    def call(method, endpoint, data)
      uri = URI ("#{@api_base}#{endpoint}")
      http = self.get_http_client uri

      puts "Calling #{method} #{@api_base}#{endpoint}"

      if method == "POST"
        request = Net::HTTP::Post.new(uri,
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@access_token}")
        if data
          request.body = data.to_json
        end

        response = http.request request
        puts response, response.code, response.body
        return response
      end

      if method == "GET"
        request = Net::HTTP::Get.new(uri,
          'Authorization' => "Bearer #{@access_token}")
        response = http.request request
        puts response, response.code, response.body
        return response
      end

      raise "Method not implemented"
    end
  end
end