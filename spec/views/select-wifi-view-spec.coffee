SettingsHelper = require '../../lib/utils/settings-helper'
SelectWifiView = require '../../lib/views/select-wifi-view'
_s = require 'underscore.string'

describe 'Select Wifi View', ->
  activationPromise = null
  sparkIde = null
  selectWifiView = null
  originalProfile = null
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('spark-dev').then ({mainModule}) ->
      sparkIde = mainModule
      selectWifiView = new SelectWifiView

    originalProfile = SettingsHelper.getProfile()
    # For tests not to mess up our profile, we have to switch to test one...
    SettingsHelper.setProfile 'spark-dev-test'

    # Mock serial
    require.cache[require.resolve('serialport')].exports = require('spark-dev-spec-stubs').serialportSuccess

    waitsForPromise ->
      activationPromise

  afterEach ->
    SettingsHelper.setProfile originalProfile

  describe '', ->
    it 'tests loading items', ->
      SettingsHelper.setCredentials 'foo@bar.baz', '0123456789abcdef0123456789abcdef'
      spyOn selectWifiView, 'listNetworks'

      selectWifiView.show()

      expect(selectWifiView.listNetworks).toHaveBeenCalled()

      jasmine.unspy selectWifiView, 'listNetworks'
      SettingsHelper.clearCredentials()
      selectWifiView.hide()

    it 'test listing networks on Darwin', ->
      SettingsHelper.setCredentials 'foo@bar.baz', '0123456789abcdef0123456789abcdef'

      process.platform = 'darwin'

      spyOn(selectWifiView, 'getPlatform').andReturn('darwin')
      spyOn(selectWifiView, 'listNetworksDarwin').andCallThrough()
      spyOn(selectWifiView.cp, 'exec').andCallFake (command, callback) ->
        if _s.endsWith(command) == '-I'
          stdout = "     agrCtlRSSI: -40\n\
     agrExtRSSI: 0\n\
    agrCtlNoise: -92\n\
    agrExtNoise: 0\n\
          state: running\n\
        op mode: station \n\
     lastTxRate: 130\n\
        maxRate: 144\n\
lastAssocStatus: 0\n\
    802.11 auth: open\n\
      link auth: wpa2-psk\n\
          BSSID: fc:91:e3:47:92:d3\n\
           SSID: foo\n\
            MCS: 15\n\
        channel: 6"

        else
          stdout = "                            SSID BSSID             RSSI CHANNEL HT CC SECURITY (auth/unicast/group)\n\
                      UPC0044189 fc:94:e3:32:3e:a8 -49  11      Y  -- NONE \n\
                     UPC Wi-Free fe:94:e3:32:3e:aa -51  11      Y  -- WPA(802.1x/AES,TKIP/TKIP) \n\
                          pstryk c8:3a:35:11:8d:b0 -83  6,-1    Y  -- WEP \n\
                     UPC Wi-Free fe:94:e3:21:92:d5 -36  6       Y  -- WPA(802.1x/AES,TKIP/TKIP) \n\
                             foo fc:94:e3:21:92:d3 -37  6       Y  -- WPA(PSK/AES,TKIP/TKIP) WPA2(PSK/AES,TKIP/TKIP) "

        callback '', stdout

      spyOn selectWifiView, 'setItems'

      selectWifiView.show()

      runs ->
        expect(selectWifiView.find('span.loading-message').text()).toEqual('Scaning for networks...')
        expect(selectWifiView.listNetworksDarwin).toHaveBeenCalled()

        expect(selectWifiView.setItems).toHaveBeenCalled()
        expect(selectWifiView.setItems.calls.length).toEqual(2)

        args = selectWifiView.setItems.calls[0].args[0]
        expect(args.length).toEqual(1)
        expect(args[0].ssid).toEqual('Enter SSID manually')
        expect(args[0].security).toBe(null)

        args = selectWifiView.setItems.calls[1].args[0]
        expect(args.length).toEqual(5)
        expect(args[0].ssid).toEqual('foo')
        expect(args[0].bssid).toEqual('fc:94:e3:21:92:d3')
        expect(args[0].rssi).toEqual('-37')
        expect(args[0].channel).toEqual('6')
        expect(args[0].ht).toEqual('Y')
        expect(args[0].cc).toEqual('--')
        expect(args[0].security_string).toEqual('WPA(PSK/AES,TKIP/TKIP) WPA2(PSK/AES,TKIP/TKIP) ')
        expect(args[0].security).toEqual(3)

        expect(args[1].security).toEqual(0)
        expect(args[2].security).toEqual(2)
        expect(args[3].security).toEqual(1)

        expect(args[4].ssid).toEqual('Enter SSID manually')
        expect(args[4].security).toBe(null)

        jasmine.unspy selectWifiView, 'setItems'
        jasmine.unspy selectWifiView.cp, 'exec'
        jasmine.unspy selectWifiView, 'listNetworksDarwin'
        jasmine.unspy selectWifiView, 'getPlatform'
        SettingsHelper.clearCredentials()
        selectWifiView.hide()

    it 'test listing networks on Windows', ->
      SettingsHelper.setCredentials 'foo@bar.baz', '0123456789abcdef0123456789abcdef'
      sparkIde.selectWifiView = null
      sparkIde.initView 'select-wifi'
      selectWifiView = sparkIde.selectWifiView
      spyOn(selectWifiView, 'getPlatform').andReturn('win32')

      spyOn(selectWifiView, 'listNetworksWindows').andCallThrough()
      spyOn(selectWifiView.cp, 'exec').andCallFake (command, callback) ->
        fs = require 'fs-plus'
        if command.indexOf('show interfaces') > -1
          stdout = fs.readFileSync __dirname + '/../data/interfaces-win.txt'
        else
          stdout = fs.readFileSync __dirname + '/../data/networks-win.txt'

        callback '', stdout.toString()

      spyOn selectWifiView, 'setItems'

      selectWifiView.show()

      runs ->
        expect(selectWifiView.find('span.loading-message').text()).toEqual('Scaning for networks...')
        expect(selectWifiView.listNetworksWindows).toHaveBeenCalled()

        expect(selectWifiView.setItems).toHaveBeenCalled()
        expect(selectWifiView.setItems.calls.length).toEqual(2)

        args = selectWifiView.setItems.calls[0].args[0]
        expect(args.length).toEqual(1)
        expect(args[0].ssid).toEqual('Enter SSID manually')
        expect(args[0].security).toBe(null)

        args = selectWifiView.setItems.calls[1].args[0]
        expect(args.length).toEqual(6)
        expect(args[0].ssid).toEqual('foo')
        expect(args[0].bssid).toEqual('c8:d7:19:39:a6:74')
        expect(args[0].rssi).toEqual('96')
        expect(args[0].channel).toEqual('3')
        expect(args[0].authentication).toEqual('WPA2-Personal')
        expect(args[0].encryption).toEqual('CCMP')
        expect(args[0].security).toEqual(3)

        expect(args[1].security).toEqual(2)
        expect(args[2].security).toEqual(3)
        expect(args[3].security).toEqual(0)
        expect(args[4].security).toEqual(1)

        expect(args[5].ssid).toEqual('Enter SSID manually')
        expect(args[5].security).toBe(null)

        jasmine.unspy selectWifiView, 'setItems'
        jasmine.unspy selectWifiView.cp, 'exec'
        jasmine.unspy selectWifiView, 'listNetworksWindows'
        jasmine.unspy selectWifiView, 'getPlatform'
        SettingsHelper.clearCredentials()
        selectWifiView.hide()

    it 'tests selecting item', ->
      SettingsHelper.setCredentials 'foo@bar.baz', '0123456789abcdef0123456789abcdef'
      spyOn selectWifiView, 'listNetworksDarwin'

      selectWifiView.show()

      runs ->
        spyOn sparkIde.emitter, 'emit'

        selectWifiView.confirmed selectWifiView.items[0]

        expect(sparkIde.emitter.emit).toHaveBeenCalled()
        expect(sparkIde.emitter.emit).toHaveBeenCalledWith('spark-dev:enter-wifi-credentials', { port: null})

        jasmine.unspy sparkIde.emitter, 'emit'
        jasmine.unspy selectWifiView, 'listNetworksDarwin'
        SettingsHelper.clearCredentials()
        selectWifiView.hide()
