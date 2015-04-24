{$, View, TextEditorView} = require 'atom-space-pen-views'

$ = null
_s = null
SettingsHelper = null
validator = null
SerialHelper = null

module.exports =
class WifiCredentialsView extends View
  @content: ->
    @div id: 'spark-dev-wifi-credentials-view', class: 'overlay from-top', =>
      @div class: 'block', =>
        @span 'Enter WiFi Credentials '
        @span class: 'text-subtle', =>
          @text 'Close this dialog with the '
          @span class: 'highlight', 'esc'
          @span ' key'
      @subview 'ssidEditor', new TextEditorView(mini: true, placeholderText: 'SSID')
      @div class: 'security', =>
        @label =>
          @input type: 'radio', name: 'security', value: '0', checked: 'checked', change: 'change'
          @span 'Unsecured'
        @label =>
          @input type: 'radio', name: 'security', value: '1', change: 'change'
          @span 'WEP'
        @label =>
          @input type: 'radio', name: 'security', value: '2', change: 'change'
          @span 'WPA'
        @label =>
          @input type: 'radio', name: 'security', value: '3', change: 'change'
          @span 'WPA2'
      @subview 'passwordEditor', new TextEditorView(mini: true, placeholderText: 'and a password?')
      @div class: 'text-error block', outlet: 'errorLabel'
      @div class: 'block', =>
        @button click: 'save', id: 'saveButton', class: 'btn btn-primary', outlet: 'saveButton', 'Save'
        @button click: 'cancel', id: 'cancelButton', class: 'btn', outlet: 'cancelButton', 'Cancel'
        @span class: 'three-quarters inline-block hidden', outlet: 'spinner'

  initialize: (serializeState) ->
    {CompositeDisposable} = require 'atom'
    _s ?= require 'underscore.string'
    SettingsHelper = require '../utils/settings-helper'
    SerialHelper = require '../utils/serial-helper'


    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'core:cancel', => @remove()
      'core:close', => @remove()

    @security = '0'
    @passwordEditor.addClass 'hidden'

    @serialWifiConfigPromise = null


  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @remove()
    @disposables.dispose()

  show: (ssid=null, security=null) =>
    if !@hasParent()
      atom.workspaceView.append(this)
      if ssid
        @ssidEditor.getEditor().setText ssid
      else
        @ssidEditor.focus()

      if security
        input = @find 'input[name=security][value=' + security + ']'
        input.attr 'checked', 'checked'
        input.change()

      @errorLabel.hide()

  hide: ->
    if @hasParent()
      @detach()

  cancel: (event, element) =>
    if !!@loginPromise
      @loginPromise = null
    @unlockUi()
    @clearErrors()
    @hide()

  cancelCommand: ->
    @cancel()

  # Remove errors from inputs
  clearErrors: ->
    @ssidEditor.removeClass 'editor-error'
    @passwordEditor.removeClass 'editor-error'

  change: ->
    @security = @find('input[name=security]:checked').val()

    if @security == '0'
      @passwordEditor.addClass 'hidden'
    else
      @passwordEditor.removeClass 'hidden'
      @passwordEditor.focus()

  # Test input's values
  validateInputs: ->
    validator ?= require 'validator'

    @clearErrors()

    @ssid = _s.trim(@ssidEditor.getText())
    @password = _s.trim(@passwordEditor.getText())

    isOk = true

    if @ssid == ''
      @ssidEditor.addClass 'editor-error'
      isOk = false

    if (@security != '0') && (@password == '')
      @passwordEditor.addClass 'editor-error'
      isOk = false

    isOk

  # Unlock inputs and buttons
  unlockUi: ->
    @ssidEditor.hiddenInput.removeAttr 'disabled'
    @find('input[name=security]').removeAttr 'disabled'
    @passwordEditor.hiddenInput.removeAttr 'disabled'
    @saveButton.removeAttr 'disabled'

  save: ->
    if !@validateInputs()
      return false

    @ssidEditor.hiddenInput.attr 'disabled', 'disabled'
    @find('input[name=security]').attr 'disabled', 'disabled'
    @passwordEditor.hiddenInput.attr 'disabled', 'disabled'
    @saveButton.attr 'disabled', 'disabled'
    @spinner.removeClass 'hidden'
    @errorLabel.hide()

    @serialWifiConfigPromise = SerialHelper.serialWifiConfig @port, @ssid, @password, @security
    @serialWifiConfigPromise.done (e) =>
      @spinner.addClass 'hidden'

      @cancel()
      @serialWifiConfigPromise = null
    , (e) =>
      @spinner.addClass 'hidden'
      @unlockUi()
      @errorLabel.text(e).show()
      @serialWifiConfigPromise = null
