require 'savon'
require 'httparty'
require 'builder/xchar'
require 'live_identity'
require 'base64'

# Disable SSL check, need to use proper certs
# FIXME
VerifyA = false
VerifyB = :none

module XLiveServices
    def self.GetLcwConfig(locale)
        data = HTTParty.get("https://live.xbox.com/#{locale}/GetLcwConfig.ashx", :format => :xml, :verify => VerifyA) # FIXME
        XLiveServices.ParseConfig(data)
    end

    def self.ParseConfig(config)
        parsed = { :Auth => {}, :URL => {} }
        config['Environment']['Authentication']['AuthSetting'].each do |setting|
            parsed[:Auth][setting['name'].to_sym] = { ServiceName: setting['serviceName'], Policy: setting['policy'].to_sym }
        end
        config['Environment']['UrlSettings']['UrlSetting'].each do |setting|
            parsed[:URL][setting['name'].to_sym] = [ setting['url'], setting['authKey'].empty? ? nil : setting['authKey'].to_sym ]
        end
        parsed
    end

    def self.DoAuth(identity, serviceName, policy)
        tries ||= 5
        identity.AuthToService(serviceName, policy, :SERVICE_TOKEN_FROM_CACHE)
    rescue LiveIdentity::LiveIdentityError => e
        retry if e.code == LiveIdentity::IDCRL::HRESULT::PPCRL_E_UNABLE_TO_RETRIEVE_SERVICE_TOKEN and not (tries -= 1).zero?
    end

    def self.GetUserAuthService(identity, config)
        configData = config[:Auth][config[:URL][:GetUserAuth].last]
        DoAuth(identity, configData[:ServiceName], configData[:Policy])
    end

    def self.GetWgxService(identity, config)
        configData = config[:Auth][config[:URL][:WgxService].last]
        DoAuth(identity, configData[:ServiceName], configData[:Policy])
    end

    def self.GetUserAuthorization(url, userAuthService)
        data = HTTParty.post(url, :format => :xml,
        :body => { :serviceType => 1, :titleId => 0 },
        :headers => { 'Authorization' => "WLID1.0 #{userAuthService.Token}", 'X-ClientType' => 'panorama' })
    end

    def self.BuildHeader(endpoint, action, compactRPSTicket)
        %{
        <a:Action s:mustUnderstand="1">#{action}</a:Action>
        <a:To s:mustUnderstand="1">#{endpoint}</a:To>
        <o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <cct:RpsSecurityToken wsu:Id="00000000-0000-0000-0000-000000000000" xmlns:cct="http://samples.microsoft.com/wcf/security/Extensibility/" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <cct:RpsTicket>#{Builder::XChar.encode(compactRPSTicket)}</cct:RpsTicket>
          </cct:RpsSecurityToken>
        </o:Security>
    }
    end

    def self.BuildAction(namespace, configurationName, name)
        namespace + configurationName + '/' + name
    end

    class Serialization
        def self.Serialize(type, data)
            serialized = {}
            case type
            when 'enum'
                serialized = data.to_s
            when 'uint[]'
                serialized[:'@xmlns:b'] = 'http://schemas.microsoft.com/2003/10/Serialization/Arrays'
                serialized[:content!] = { 'b:unsignedInt' => data }
            when 'string[]'
                serialized[:'@xmlns:b'] = 'http://schemas.microsoft.com/2003/10/Serialization/Arrays'
                serialized[:content!] = { 'b:string' => data }
            end
            serialized
        end
    end

    class MarketplacePublic
        extend Savon::Model
        client endpoint: '', namespace: 'http://tempuri.org/'
        global :env_namespace, :s
        global :namespace_identifier, :t
        global :convert_request_keys_to, :none
        global :element_form_default, :qualified
        global :convert_response_tags_to, :camelcase
        global :soap_version, 2
        global :namespaces, { 'xmlns:a' => 'http://www.w3.org/2005/08/addressing' }
        global :ssl_verify_mode, VerifyB # FIXME
        global :log_level, :debug
        global :log, false

        ConfigurationName = 'IMarketplacePublic'

        module SortField
            Title = :Title
            AvailabilityDate = :AvailabilityDate
            LastPlayedDate = :LastPlayedDate
        end

        def initialize(endpoint, wgxService)
            @WgxService = wgxService
            client.globals[:endpoint] = endpoint
        end

        def self.BuildOfferGUID(titleId, offerID)
            "#{offerID}-0000-4000-8000-0000%08x" % titleId
        end

        def BuildOfferGUID(titleId, offerID)
            self.class.BuildOfferGUID(titleId, offerID)
        end

        def GetHeader(name)
            XLiveServices::BuildHeader(client.globals[:endpoint], XLiveServices::BuildAction(client.globals[:namespace], ConfigurationName, name.to_s), @WgxService.Token)
        end

        def GetPurchaseHistory(locale, pageNum = 1, orderBy = SortField::Title)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { locale: locale, pageNum: pageNum, orderBy: Serialization::Serialize('enum', orderBy) }
        end

        def ReadUserSettings(titleID, settings)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { titleID: titleID, settings: Serialization::Serialize('uint[]', settings) }
        end

        def GetOfferDetailsPublic(locale, offerGUID)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { locale: locale, offerId: offerGUID }
        end

        def GetLicensePublic(offerGUID)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { offerId: offerGUID }
        end

        def GetSponsorToken(titleId)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { titleId: titleId }
        end

        def GetActivationKey(offerGUID)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { offerId: offerGUID }
        end

        def GetMediaUrls(urls, offerGUID)
            client.globals[:soap_header] = GetHeader(__callee__)
            client.call __callee__, message: { urls: Serialization::Serialize('string[]', urls), offerID: offerGUID }
        end

    end

end

locale = 'en-US'

config = XLiveServices.GetLcwConfig(locale)

options = { :IDCRL_OPTION_ENVIRONMENT => 'Production' }

live = LiveIdentity.new('{D34F9E47-A73B-44E5-AE67-5D0D8B8CFA76}', 1, :NO_UI, options)

identity = live.GetIdentity('yourLive@Id.com', :IDENTITY_SHARE_ALL)

# Missing few things, not implemented yet
# TODO
#

userAuthService = XLiveServices.GetUserAuthService(identity, config)

userAuthorizationInfo = XLiveServices.GetUserAuthorization(config[:URL][:GetUserAuth].first, userAuthService)

accountInfo = userAuthorizationInfo['GetUserAuthorizationInfo']['AccountInfo']
puts '=== AccountInfo ==='
puts "XboxPuid: #{accountInfo['XboxPuid']}"
puts "LivePuid: #{accountInfo['LivePuid']}"
puts "Tag: #{accountInfo['Tag']}"
puts "CountryCode: #{accountInfo['CountryCode']}"

puts '=== Subscriptions ==='
subscriptions = userAuthorizationInfo['GetUserAuthorizationInfo']['SubscriptionInfo']['Subscription']
subscriptions = [] unless subscriptions
subscriptions = [subscriptions] unless subscriptions.is_a?(Array)
subscriptions.each do |sub|
    puts "OfferId: #{sub['OfferId']}"
    puts "Status: #{sub['Status']}"
    puts "StartDate: #{sub['StartDate']}"
    puts "EndDate: #{sub['EndDate']}"
    puts
end

wgxService = XLiveServices.GetWgxService(identity, config)

# IDK about this service url 'https://services.gamesforwindows.com/SecurePublic/MarketplaceRestSecure.svc'

marketplace = XLiveServices::MarketplacePublic.new(config[:URL][:WgxService].first, wgxService)

response = marketplace.GetPurchaseHistory(locale)
purchaseHistoryResult = response.body["GetPurchaseHistoryResponse"]["GetPurchaseHistoryResult"]

puts "Purchase Offer count: #{purchaseHistoryResult['TotalCount']}"

puts '=== Purchase Offers ==='
offers = purchaseHistoryResult['Offers']
offerData = []
offerData = offers['OfferData'] unless offers.nil?
offerData = [offerData] unless offerData.is_a?(Array)
offerData.each do |data|
    puts "GameTitle: #{data['GameTitle']}"
    puts "Title: #{data['Title']}"
    puts "DeveloperName: #{data['DeveloperName']}"
    puts "PublisherName: #{data['PublisherName']}"
    puts "Description: #{data['Description']}"
    puts "GameTitleMediaId: #{data['GameTitleMediaId']}"
    puts "MediaId: #{data['MediaId']}"
    puts "OfferId: #{data['OfferId']}"
    puts
end

TitleID = 0x4d5308d2
offerGUID = marketplace.BuildOfferGUID(TitleID, 'e0000001')

response = marketplace.GetOfferDetailsPublic(locale, offerGUID)
offerDetailsPublicResult = response.body["GetOfferDetailsPublicResponse"]["GetOfferDetailsPublicResult"]

puts "GameTitle: #{offerDetailsPublicResult['GameTitle']}"
puts "Title: #{offerDetailsPublicResult['Title']}"
puts "Developer: #{offerDetailsPublicResult['Developer']}"
puts "Publisher: #{offerDetailsPublicResult['Publisher']}"
puts "Description: #{offerDetailsPublicResult['Description']}"
puts "GameTitleMediaId: #{offerDetailsPublicResult['GameTitleMediaId']}"
puts "MediaId: #{offerDetailsPublicResult['MediaId']}"
puts "OfferId: #{offerDetailsPublicResult['OfferId']}"

mediaInstance = offerDetailsPublicResult['MediaInstances']['MediaInstance']

puts "ContentId: #{mediaInstance['ContentId']}"
puts "InstallSize: #{mediaInstance['InstallSize']}"
puts "MediaInstanceId: #{mediaInstance['MediaInstanceId']}"

urls = mediaInstance['Urls']['string']
urls = [] unless urls
urls = [urls] unless urls.is_a?(Array)
urls.each do |url|
    puts 'URL: ' + url
end

contentID = Base64.decode64(mediaInstance['ContentId']).unpack('H*').first.upcase

puts "hexContentId: #{contentID}"

mediaUrls = []

# Actually proper way would be to download manifest cab, extract and get links from 'Content\OfferManifest.xml' file
mediaUrls << "http://download.gfwl.xboxlive.com/content/gfwl/%08X/#{contentID}_1.cab" % TitleID

response = marketplace.GetMediaUrls(mediaUrls, offerGUID)
mediaUrlsResult = response.body["GetMediaUrlsResponse"]["GetMediaUrlsResult"]
if (mediaUrlsResult['HResult'].to_i.zero?)
    urls = mediaUrlsResult['Urls']['string']
    urls = [] unless urls
    urls = [urls] unless urls.is_a?(Array)
    urls.each do |url|
        puts 'Media URL: ' + url
    end
else
    puts "ERROR: 0x%08X" % mediaUrlsResult['HResult'].to_i
end
