require 'optparse'
require 'xlive_services'

def getOptions
    options = {
        :UserName => nil, :Password => nil, :Locale => 'en-US',
        :Save => false, :Remove => false,
        :Account => false, :Subscriptions => false, :History => nil,
        :Command => :none, :OfferID => nil, :TitleID => nil,
        :URLS => []
    }
    parser = OptionParser.new do |opts|
        opts.banner = 'Usage: xlive [options]'
        opts.on('-u','--username USERNAME', 'Your Windows Live username') do |username|
            options[:UserName] = username
        end
        opts.on('-p', '--password PASSWORD', 'Password for account') do |password|
            options[:Password] = password
        end
        opts.on('-l', '--locale LOCALE', 'Locale (default "en-US")') do |locale|
            options[:Locale] = locale
        end
        opts.on('--[no-]save', 'Persist credentials') do |save|
            options[:Save] = save
        end
        opts.on('-d', '--[no-]delete', 'Remove credentials') do |remove|
            options[:Remove] = remove
        end
        opts.on('-a', '--[no-]account', 'Display information about account') do |account|
            options[:Account] = account
        end
        opts.on('-s', '--[no-]subscriptions', 'Display information about subscriptions') do |subscriptions|
            options[:Subscriptions] = subscriptions
        end
        opts.on('-c','--command COMMAND', [:none, :purchasehistory, :offerdetails, :mediaurls], "Command to execute (none, purchasehistory,\n#{' '*37}offerdetails, mediaurls)") do |command|
            options[:Command] = command
        end
        opts.on('-o','--offer OFFER', "Offer ID (eg. 0x584109ebe0000001,\n#{' '*37}0xE0000001)") do |offer|
            if offer.downcase.start_with?('0x')
                options[:OfferID] = offer.to_i(16)
            else
                options[:OfferID] = offer.to_i
            end

        end
        opts.on('-t','--title TITLE', 'Tittle ID (eg. 0x584109eb)') do |title|
            if title.downcase.start_with?('0x')
                options[:TitleID] = title.to_i(16)
            else
                options[:TitleID] = title.to_i
            end
        end
        opts.on('--urls url1,url2', Array, 'List of Media Urls') do |urls|
            options[:URLS] = urls
        end
        opts.on_tail('-h', '--help', 'Show this message') do
            puts opts
            return false
        end
    end
    begin
        parser.parse!
    rescue OptionParser::ParseError => e
        $stderr.puts e.message
        return false
    end
    return options
end

def getOfferGUID(options, marketplace)
    if (options[:OfferID].nil?)
        puts 'No OfferID specified!'
        return false
    end
    marketplace.BuildOfferGUID(options[:OfferID], options[:TitleID])
end

def main
    options = getOptions
    return false unless options

    begin
        xlive = XLiveServices::XLive.new(options[:UserName], options[:Password], options[:Locale])
    rescue XLiveServices::XLiveServicesError => e
        puts "Error: #{e.message}"
        return false
    end

    if options[:Save]
        xlive.PersistCredentials()
        puts 'Credentials Saved!'
    end

    if options[:Remove]
        xlive.RemovePersistedCredentials()
        puts 'Credentials Removed!'
    end

    if !xlive.IsAuthenticated?
        puts "Authenticating #{xlive.Username}... Please wait..."
        xlive.Authenticate()
        puts 'Authenticated!'
    end

    userAuthorizationInfo = xlive.GetUserAuthorizationInfo()
    accountInfo = userAuthorizationInfo['AccountInfo']

    if options[:Account]
        puts '=== AccountInfo ==='
        puts "XboxPuid: #{accountInfo['XboxPuid']}"
        puts "LivePuid: #{accountInfo['LivePuid']}"
        puts "Tag: #{accountInfo['Tag']}"
        puts "CountryCode: #{accountInfo['CountryCode']}"
    end

    if options[:Subscriptions]
        puts '=== Subscriptions ==='
        subscriptions = userAuthorizationInfo['SubscriptionInfo']['Subscription']
        subscriptions = [] unless subscriptions
        subscriptions = [subscriptions] unless subscriptions.is_a?(Array)
        subscriptions.each do |sub|
            puts "OfferId: #{sub['OfferId']}"
            puts "Status: #{sub['Status']}"
            puts "StartDate: #{sub['StartDate']}"
            puts "EndDate: #{sub['EndDate']}"
            puts
        end
    end

    return true if options[:Command] == :none

    puts "Connecting to Marketplace"
    marketplace = xlive.GetMarketplace()

    case options[:Command]
    when :purchasehistory
        response = marketplace.GetPurchaseHistory(xlive.Locale)
        purchaseHistoryResult = response.body["GetPurchaseHistoryResponse"]["GetPurchaseHistoryResult"]

        puts "\nPurchase Offer count: #{purchaseHistoryResult['TotalCount']}"

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
    when :offerdetails
        offerGUID = getOfferGUID(options, marketplace)
        return false unless offerGUID
        puts "Executing GetOfferDetailsPublic(#{xlive.Locale}, #{offerGUID})"
        begin
            response = marketplace.GetOfferDetailsPublic(xlive.Locale, offerGUID)
        rescue Savon::SOAPFault => e
            puts "Error: #{e.message}"
            return false
        end
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
    when :mediaurls
        offerGUID = getOfferGUID(options, marketplace)
        return false unless offerGUID
        if (options[:URLS].empty?)
            puts 'No URLs specified!'
            return false
        end
        puts "Executing GetMediaUrls(#{offerGUID})"
        response = marketplace.GetMediaUrls(options[:URLS], offerGUID)
        mediaUrlsResult = response.body["GetMediaUrlsResponse"]["GetMediaUrlsResult"]
        if (mediaUrlsResult['HResult'].to_i.zero?)
            urls = mediaUrlsResult['Urls']['string']
            urls = [] unless urls
            urls = [urls] unless urls.is_a?(Array)
            urls.each do |url|
                puts 'Media URL: ' + url
            end
        else
            puts "ERROR: #{WinCommon::Errors::HRESULT::GetNameCode(mediaUrlsResult['HResult'].to_i)}"
        end
    end

end

main unless $spec
