Dialog = require '../subviews/dialog'
SettingsHelper = null
_s = null

module.exports =
class ClaimCoreView extends Dialog
  constructor: ->
    super
      prompt: 'Enter device ID (hex string)'
      initialText: ''
      select: false
      iconClass: ''
      hideOnBlur: false

    @claimPromise = null
    @prop 'id', 'spark-dev-claim-core-view'

  # When deviceID is submited
  onConfirm: (deviceID) ->
    SettingsHelper ?= require '../utils/settings-helper'
    _s ?= require 'underscore.string'

    # Remove any errors
    @miniEditor.removeClass 'editor-error'
    # Trim deviceID from any whitespaces
    deviceID = _s.trim(deviceID)

    if deviceID == ''
      # Empty deviceID is not allowed
      @miniEditor.addClass 'editor-error'
    else
      # Lock input
      @miniEditor.hiddenInput.attr 'disabled', 'disabled'

      spark = require 'spark'
      spark.login { accessToken: SettingsHelper.get('access_token') }
      workspace = atom.workspaceView
      # Claim core via API
      @claimPromise = spark.claimCore deviceID
      @setLoading true
      @claimPromise.done (e) =>
        @setLoading false
        if e.ok
          if !@claimPromise
            return

          # Set current core in settings
          SettingsHelper.setCurrentCore e.id, null

          # Refresh UI
          atom.workspaceView.trigger 'spark-dev:update-core-status'
          atom.workspaceView.trigger 'spark-dev:update-menu'

          @claimPromise = null
          @close()
        else
          @miniEditor.hiddenInput.removeAttr 'disabled'
          @miniEditor.addClass 'editor-error'
          @showError e.errors
          @claimPromise = null

      , (e) =>
        @setLoading false
        # Show error
        @miniEditor.hiddenInput.removeAttr 'disabled'

        if e.code == 'ENOTFOUND'
          message = 'Error while connecting to ' + e.hostname
          @showError message
        else
          @miniEditor.addClass 'editor-error'
          @showError e.errors

        @claimPromise = null
