require 'savon'
require 'httparty'
require 'builder/xchar'

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

    def self.Authenticate(url)
        # TODO
    end

    def self.BuildHeader(wgxService, action, compactRPSTicket)
        %{
        <a:Action s:mustUnderstand="1">#{action}</a:Action>
        <a:To s:mustUnderstand="1">#{wgxService}</a:To>
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
                # TODO
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
            Title = 1
            AvailabilityDate = 2
            LastPlayedDate = 3
        end

        def initialize(wgxService, compactRPSTicket)
            @WgxService = wgxService
            @CompactRPSTicket = compactRPSTicket
            client.globals[:endpoint] = @WgxService
        end

        def self.BuildOfferGUID(titleId, offerID)
            "#{offerID}-0000-4000-8000-0000#{titleId.to_s(16)}"
        end

        def BuildOfferGUID(titleId, offerID)
            self.class.BuildOfferGUID(titleId, offerID)
        end

        def GetHeader(name)
            XLiveServices::BuildHeader(@WgxService, XLiveServices::BuildAction(client.globals[:namespace], ConfigurationName, name.to_s), @CompactRPSTicket)
        end

        def GetPurchaseHistory(locale, pageNum, orderBy)
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

#ticket = XLiveServices.Authenticate(config[:URL][:GetUserAuth].first)
# Relying Party Suite (RPS) Auth Token
ticket = 't=PUT-HERE-YOUR-Base64encoded-RPSTicket&p='

# IDK about this service url 'https://services.gamesforwindows.com/SecurePublic/MarketplaceRestSecure.svc'

marketplace = XLiveServices::MarketplacePublic.new(config[:URL][:WgxService].first, ticket)

response = marketplace.GetOfferDetailsPublic(locale, marketplace.BuildOfferGUID(0x425307d6, 'e0000001'))

offerDetailsPublicResult = response.body["GetOfferDetailsPublicResponse"]["GetOfferDetailsPublicResult"]

#require 'pp'
#pp response.body

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

mediaInstance['Urls']['string'].each do |url|
    puts 'URL: ' + url
end

