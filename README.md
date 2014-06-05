# XLiveClient

Application to interact with Xbox LIVE and Games for Windows LIVE services

## Installation

`git clone https://github.com/davispuh/XLiveClient.git`

### Dependencies

gems:

* `XLiveServices` (required)

install manually (`gem install`) or with

`bundle install`

## Usage

for command information use `-h` or `--help` flag

`ruby xlive.rb -h`

```
Usage: xlive [options]
    -u, --username USERNAME          Your Windows Live username
    -p, --password PASSWORD          Password for account
    -l, --locale LOCALE              Locale (default "en-US")
        --[no-]save                  Persist credentials
    -d, --[no-]delete                Remove credentials
    -a, --[no-]account               Display information about account
    -s, --[no-]subscriptions         Display information about subscriptions
    -c, --command COMMAND            Command to execute (none, purchasehistory,
                                     offerdetails, mediaurls)
    -o, --offer OFFER                Offer ID (eg. 0x584109ebe0000001,
                                     0xE0000001)
    -t, --title TITLE                Tittle ID (eg. 0x584109eb)
        --urls url1,url2             List of Media Urls
    -h, --help                       Show this message
```

### In action

```bash
$ ruby xlive.rb -u account@live.com -p 12345 --save -c offerdetails -o 0x584109ebe0000001
Authenticating account@live.com... Please wait...
Authenticated!
Connecting to Marketplace
Executing GetOfferDetailsPublic(en-US, e0000001-0000-4000-8000-0000584109eb)
GameTitle: Tinker
Title: Tinker
Developer: FUEL GAMES
Publisher: Microsoft Game Studios
Description: Being a small robot isn’t always easy….So, imagine being a robot marooned in a surreal landscape of obscure mechanisms and brain-teasing puzzles. He’ll go where you tell him to go - but will your directions lead him home or leave him trapped?
GameTitleMediaId: 66acd000-77fe-1000-9115-d804584109eb
MediaId: 66acd000-77fe-1000-9115-d804584109eb
OfferId: e0000001-0000-4000-8000-0000584109eb
ContentId: EOcMpZ472xJvJ8/CzKjaSxlpw5Q=
InstallSize: 61809226
MediaInstanceId: 10e70ca5-9e3b-40db-8012-6f27cfc2cca8
URL: http://download.xbox.com:80/content/584109eb/10e70ca59e3bdb126f27cfc2cca8da4b1969c394_manifest.cab
URL: http://download.xbox.com.edgesuite.net:80/content/584109eb/10e70ca59e3bdb126f27cfc2cca8da4b1969c394_manifest.cab
URL: http://xbox-ecn102.vo.msecnd.net:80/content/584109eb/10e70ca59e3bdb126f27cfc2cca8da4b1969c394_manifest.cab
hexContentId: 10E70CA59E3BDB126F27CFC2CCA8DA4B1969C394
```

## Unlicense

![Copyright-Free](http://unlicense.org/pd-icon.png)

All text, documentation, code and files in this repository are in public domain (including this text, README).
It means you can copy, modify, distribute and include in your own work/code, even for commercial purposes, all without asking permission.

[About Unlicense](http://unlicense.org/)

## Contributing

Feel free to improve anything.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


**Warning**: By sending pull request to this repository you dedicate any and all copyright interest in pull request (code files and all other) to the public domain. (files will be in public domain even if pull request doesn't get merged)

Also before sending pull request you acknowledge that you own all copyrights or have authorization to dedicate them to public domain.

If you don't want to dedicate code to public domain or if you're not allowed to (eg. you don't own required copyrights) then DON'T send pull request.

