_ = require("lodash")
$Clock = require("../../clock")
$Log = require("../../log")
utils = require("../../utils")

module.exports = (Cypress, Commands) ->
  Cypress.on "test:before:run", ->
    ## remove clock before each test run, so a new one is created
    ## when user calls cy.clock()
    @state("clock", null)

  Cypress.on "before:window:load", (contentWindow) ->
    ## if a clock has been created before this event (likely before
    ## a cy.visit(), then bind that clock to the new window
    if clock = @state("clock")
      clock._bind(contentWindow)

  Cypress.on "restore", ->
    ## restore the clock if we've created one
    if clock = @state("clock")
      clock.restore(false)

  Commands.addUtility({
    clock: (subject, now, methods, options = {}) ->
      if clock = @state("clock")
        return clock

      if _.isObject(now)
        options = now
        now = undefined

      if _.isObject(methods) and !_.isArray(methods)
        options = methods
        methods = undefined

      if now? and !_.isNumber(now)
        utils.throwErrByPath("clock.invalid_1st_arg", {args: {arg: JSON.stringify(now)}})

      if methods? and not (_.isArray(methods) and _.every(methods, _.isString))
        utils.throwErrByPath("clock.invalid_2nd_arg", {args: {arg: JSON.stringify(methods)}})

      _.defaults options, {
        log: true
      }

      log = (name, message, snapshot = true, consoleProps = {}) ->
        if not options.log
          return

        details = clock._details()
        logNow = details.now
        logMethods = details.methods.slice()

        $Log.command({
          name: name
          message: message ? ""
          type: "parent"
          end: true
          snapshot: snapshot
          consoleProps: ->
            _.extend({
              "Now": logNow
              "Methods replaced": logMethods
            }, consoleProps)
        })

      clock = $Clock.create(@privateState("window"), now, methods)

      clock.tick = _.wrap clock.tick, (tick, ms) ->
        if ms? and not _.isNumber(ms)
          utils.throwErrByPath("tick.invalid_argument", {args: {arg: JSON.stringify(ms)}})

        theLog = log("tick", "#{ms}ms", false, {
          "Now": clock._details().now + ms
          "Ticked": "#{ms} milliseconds"
        })
        if theLog
          theLog.snapshot("before", {next: "after"})
        ret = tick.call(clock, ms)
        if theLog
          theLog.snapshot().end()
        return ret

      clock.restore = _.wrap clock.restore, (restore, shouldLog = true) =>
        ret = restore.call(clock)
        if shouldLog
          log("restore")
        @assign("clock", null)
        @state("clock", null)
        return ret

      log("clock")

      @assign("clock", clock)
      @state("clock", clock)

    tick: (subject, ms) ->
      clock = @state("clock")

      if not clock
        utils.throwErrByPath("tick.no_clock")

      clock.tick(ms)

      return clock
  })