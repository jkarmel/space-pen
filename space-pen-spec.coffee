describe "View", ->
  view = null
  Subview = null

  describe "View objects", ->
    TestView = null

    beforeEach ->
      class Subview extends View
        @content: (params, otherArg) ->
          @div =>
            @h2 { outlet: "header" }, params.title + " " + otherArg
            @div "I am a subview"

        initialize: (args...) ->
          @initializeCalledWith = args

      class TestView extends View
        @content: (params, otherArg) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, params.title + " " + otherArg
            @list()
            @subview 'subview', new Subview(title: "Subview", 43)
            @div ".first1class#then-id", "w/content"
            @div "#first-id.then_class", "w/other content"
            @div "#id", "w/content", data: "and attrs"
            @div "#id", data: "w/attrs", "and content"
            @div ".treated-as#content"
            @div "also-treated-as#content", data: "test"
            @div "#first-id#second-id", "w/content"
            @div ".1bad-identifier#-2bad-identifier", "w/content"

        @list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        initialize: (args...) ->
          @initializeCalledWith = args

        foo: "bar",
        li1Clicked: ->,
        li2Keypressed: ->
        viewClicked: ->
        appendSpan: ->
          @append $$ @, ->
            @span click: 'spanClicked', 'span text'
        spanClicked: ->
          @spanClickedCalled = true

      view = new TestView({title: "Zebra"}, 42)

    describe "constructor", ->
      it "calls the content class method with the given params to produce the view's html", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra 42)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "calls initialize on the view with the given params", ->
        expect(view.initializeCalledWith).toEqual([{title: "Zebra"}, 42])

      it "wires outlet referenecs to elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector "li.foo:contains(one)"
        expect(view.li2).toMatchSelector "li.bar:contains(two)"

      it "removes the outlet attribute from markup", ->
        expect(view.li1.attr('outlet')).toBeUndefined()
        expect(view.li2.attr('outlet')).toBeUndefined()

      it "constructs and wires outlets for subviews", ->
        expect(view.subview).toExist()
        expect(view.subview.find('h2:contains(Subview 43)')).toExist()
        expect(view.subview.parentView).toBe view
        expect(view.subview.initializeCalledWith).toEqual([{title: "Subview"}, 43])

      it "does not overwrite outlets on the superview with outlets from the subviews", ->
        expect(view.header).toMatchSelector "h1"
        expect(view.subview.header).toMatchSelector "h2"

      it "binds events for elements with event name attributes", ->
        spyOn(view, 'viewClicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'keydown'
          expect(elt).toMatchSelector "div.rootDiv"

        spyOn(view, 'li1Clicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'click'
          expect(elt).toMatchSelector 'li.foo:contains(one)'

        spyOn(view, 'li2Keypressed').andCallFake (event, elt) ->
          expect(event.type).toBe 'keypress'
          expect(elt).toMatchSelector "li.bar:contains(two)"

        view.keydown()
        expect(view.viewClicked).toHaveBeenCalled()

        view.li1.click()
        expect(view.li1Clicked).toHaveBeenCalled()
        expect(view.li2Keypressed).not.toHaveBeenCalled()

        view.li1Clicked.reset()

        view.li2.keypress()
        expect(view.li2Keypressed).toHaveBeenCalled()
        expect(view.li1Clicked).not.toHaveBeenCalled()

      it "makes the view object accessible via the calling 'view' method on any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

      it "renders content when the first argument doesn't start with '.' or '#'", ->
        expect(view.find("also-treated-as#content")).not.toExist()
        expect(view.find("[data='test']:contains(also-treated-as#content)")).toExist()

      describe "when the first argument is a selector", ->
        it "renders an element with appropriate class and id", ->
          expect(view.find(".first1class#then-id")).toHaveText("w/content")
          expect(view.find("#first-id.then_class")).toHaveText("w/other content")

        it "renders the selector as content when it is the only argument", ->
          expect(view.find(".treated-as#content")).not.toExist()
          expect(view.find(":contains(.treated-as#content)")).toExist()

        it "only renders one id", ->
          expect(view.find("#first-id")).toExist()
          expect(view.find("#second-id")).not.toExist()

        it "doesn't render bad identifiers", ->
          expect(view.html().match(/1bad-identifier/)).toBeNull()
          expect(view.find(".1bad-identifier")).not.toExist();
          expect(view.html().match(/-2bad-identifier/)).toBeNull()
          expect(view.find("#-2bad-identifier")).not.toExist();

        it "renders attributes and content properly", ->
          expect(view.find("#id[data='and attrs']")).toHaveText("w/content")
          expect(view.find("#id[data='w/attrs']")).toHaveText("and content")

      it "defaults the first argument passed to @content and initialize to {}", ->
        contentCalledWith = null
        initializeCalledWith = null

        class TestView extends View
          @content: (params) ->
            contentCalledWith = params
            @div()

          initialize: (params) ->
            initializeCalledWith = params

        new TestView

        expect(contentCalledWith).toEqual {}
        expect(initializeCalledWith).toEqual {}

      it "throws an exception if the view has more than one root element", ->
        class BadView extends View
          @content: ->
            @div id: 'one'
            @div id: 'two'

        expect(-> new BadView).toThrow("View markup must have a single root element")

      it "throws an exception if the view has no content", ->
        BadView = class extends View
          @content: -> # left blank intentionally

        expect(-> new BadView).toThrow("View markup must have a single root element")

    describe "when a view is attached to another element via jQuery", ->
      [content, view2, view3, view4] = []

      beforeEach ->
        view2 = new TestView
        view3 = new TestView
        view4 = new TestView

        view.afterAttach = jasmine.createSpy 'view.afterAttach'
        view.subview.afterAttach = jasmine.createSpy('view.subview.afterAttach')
        view2.afterAttach = jasmine.createSpy('view2.afterAttach')
        view3.afterAttach = jasmine.createSpy('view3.afterAttach')
        expect(view4.afterAttach).toBeUndefined()

      describe "when attached to an element that is on the DOM", ->
        beforeEach ->
          content = $('#jasmine-content')

        afterEach ->
          content.empty()

        describe "when $.fn.append is called with a single argument", ->
          it "calls afterAttach (if it is present) on the appended view and its subviews, passing true to indicate they are on the DOM", ->
            content.append view
            expect(view.afterAttach).toHaveBeenCalledWith(true)
            expect(view.subview.afterAttach).toHaveBeenCalledWith(true)

        describe "when $.fn.append is called with multiple arguments", ->
          it "calls afterAttach (if it is present) on all appended views and their subviews, passing true to indicate they are on the DOM", ->
            content.append view, view2, [view3, view4]
            expect(view.afterAttach).toHaveBeenCalledWith(true)
            expect(view.subview.afterAttach).toHaveBeenCalledWith(true)
            expect(view2.afterAttach).toHaveBeenCalledWith(true)
            expect(view3.afterAttach).toHaveBeenCalledWith(true)

        describe "when $.fn.insertBefore is called on the view", ->
          it "calls afterAttach on the view and its subviews", ->
            otherElt = $('<div>')
            content.append(otherElt)
            view.insertBefore(otherElt)
            expect(view.afterAttach).toHaveBeenCalledWith(true)
            expect(view.subview.afterAttach).toHaveBeenCalledWith(true)

        describe "when a view is attached as part of a larger dom fragment", ->
          it "calls afterAttach on the view and its subviews", ->
            otherElt = $('<div>')
            otherElt.append(view)
            content.append(otherElt)
            expect(view.afterAttach).toHaveBeenCalledWith(true)
            expect(view.subview.afterAttach).toHaveBeenCalledWith(true)

      describe "when attached to an element that is not on the DOM", ->
        it "calls afterAttach (if it is present) on the appended view, passing false to indicate it isn't on the DOM", ->
          fragment = $('<div>')
          fragment.append view
          expect(view.afterAttach).toHaveBeenCalledWith(false)

        it "doesn't call afterAttach a second time until the view is attached to the DOM", ->
          fragment = $('<div>')
          fragment.append view
          view.afterAttach.reset()

          otherFragment = $('<div>')
          otherFragment.append(fragment)
          expect(view.afterAttach).not.toHaveBeenCalled()

      it "allows $.fn.append to be called with undefined without raising an exception", ->
        view.append undefined

  describe "View.render (bound to $$)", ->
    it "renders a document fragment based on tag methods called by the given function", ->
      fragment = $$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()

    it "renders subviews", ->
      fragment = $$ ->
        @div =>
          @subview 'foo', $$ ->
            @div id: "subview"

      expect(fragment.find('div#subview')).toExist()
      expect(fragment.foo).toMatchSelector('#subview')

    describe "When passed a View element as the first param", ->

      it "can wire outlets to that View element", ->
        view.append $$ view, ->
          @div =>
            @div outlet:'span', 'span text'

        expect(view.span).toHaveText 'span text'

      it "can wire events to that element", ->
        view.appendSpan()
        view.find('span').click()
        expect(view.spanClickedCalled).toBe(true)

      it "constructs and wire outlets for subviews", ->
        view.append $$ view, ->
          @div =>
            @subview 'subview2', new Subview(title: "Subview 2", 47)

        window.__view = view
        expect(view.subview2).toExist()
        expect(view.subview2.find('h2:contains(Subview 2 47)')).toExist()
        expect(view.subview2.parentView).toBe view
        expect(view.subview2.initializeCalledWith).toEqual([{title: "Subview 2"}, 47])
