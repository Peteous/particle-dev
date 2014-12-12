{WorkspaceView} = require 'atom'
$ = require('atom').$
path = require 'path'
SettingsHelper = require '../../lib/utils/settings-helper'

describe 'Compile Errors View', ->
  activationPromise = null
  sparkIde = null
  compileErrorsView = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('spark-dev').then ({mainModule}) ->
      sparkIde = mainModule
      sparkIde.compileErrorsView = null

    waitsForPromise ->
      activationPromise

  describe '', ->
    it 'tests showing without errors', ->
      atom.workspaceView.trigger 'spark-dev:show-compile-errors'
      compileErrorsView = sparkIde.compileErrorsView
      expect(atom.workspaceView.find('#spark-dev-compile-errors-view')).toExist()

      expect(compileErrorsView.find('div.loading').css('display')).toEqual('block')
      expect(compileErrorsView.find('span.loading-message').text()).toEqual('There were no compile errors')
      expect(compileErrorsView.find('ol.list-group li').length).toEqual(0)

      compileErrorsView.hide()

    it 'tests hiding and showing', ->
      # Test core:cancel
      atom.workspaceView.trigger 'spark-dev:show-compile-errors'
      expect(atom.workspaceView.find('#spark-dev-compile-errors-view')).toExist()
      atom.workspaceView.trigger 'core:cancel'
      expect(atom.workspaceView.find('#spark-dev-compile-errors-view')).not.toExist()

      # Test core:close
      atom.workspaceView.trigger 'spark-dev:show-compile-errors'
      expect(atom.workspaceView.find('#spark-dev-compile-errors-view')).toExist()
      atom.workspaceView.trigger 'core:close'
      expect(atom.workspaceView.find('#spark-dev-compile-errors-view')).not.toExist()

    it 'tests loading and selecting items', ->
      SettingsHelper.set 'compile-status', {errors: [
        {
          message: 'Foo',
          file: 'foo.ino',
          row: 1,
          col: 2
        },{
          message: 'Bar',
          file: 'bar.ino',
          row: 3,
          col: 4
        }
      ]}
      atom.project.setPaths [path.join(__dirname, '..', 'data', 'sampleproject')]
      atom.workspaceView.trigger 'spark-dev:show-compile-errors'
      compileErrorsView = sparkIde.compileErrorsView

      errors = compileErrorsView.find('ol.list-group li')
      expect(errors.length).toEqual(2)

      expect(errors.eq(0).find('.primary-line').text()).toEqual('Foo')
      expect(errors.eq(1).find('.primary-line').text()).toEqual('Bar')

      expect(errors.eq(0).find('.secondary-line').text()).toEqual('foo.ino:1:2')
      expect(errors.eq(1).find('.secondary-line').text()).toEqual('bar.ino:3:4')

      # Test selecting
      editorSpy = jasmine.createSpy 'setCursorBufferPosition'
      spyOn(atom.workspaceView, 'open').andCallFake ->
        return {
          done: (callback) ->
            callback {
              setCursorBufferPosition: editorSpy
            }
        }
      spyOn(compileErrorsView, 'cancel').andCallThrough()

      expect(atom.workspaceView.open).not.toHaveBeenCalled()
      errors.eq(0).addClass 'selected'
      compileErrorsView.trigger 'core:confirm'
      expect(atom.workspaceView.open).toHaveBeenCalled()
      expect(atom.workspaceView.open).toHaveBeenCalledWith(
        'foo.ino',
        {searchAllPanes: true}
      )
      expect(editorSpy).toHaveBeenCalled()
      expect(editorSpy).toHaveBeenCalledWith([0, 1])
      expect(compileErrorsView.cancel).toHaveBeenCalled()

      jasmine.unspy compileErrorsView, 'cancel'
      jasmine.unspy atom.workspaceView, 'open'
      SettingsHelper.set 'compile-status', null
