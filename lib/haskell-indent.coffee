{CompositeDisposable} = require 'atom'

module.exports = HaskellIndent =
    subscriptions:  null

    activate: (state) ->
        @subscriptions  = new CompositeDisposable

        #@subscriptions.add atom.commands.add 'atom-text-editor', 'haskell-indent:smart indent', => @smartIndent()

        for te in atom.workspace.getTextEditors()
            @setTextEditor te

        @subscriptions.add atom.workspace.onDidAddTextEditor ({textEditor}) => @setTextEditor textEditor

    deactivate: ->
        @subscriptions.dispose()

    setTextEditor: (textEditor) ->
        @subscriptions.add textEditor.onDidChangeGrammar =>
            @setSmartIndent textEditor
        @setSmartIndent textEditor

    setSmartIndent: (textEditor) ->
        if textEditor.getGrammar().scopeName == 'source.haskell'
            @subscriptions.add textEditor.onDidInsertText (char) =>
                if char.text == "\n"
                    @newlineIndent(textEditor, char.range.end.row - 1)

    newlineIndent: (textEditor, row) ->
        levels = @indentLevel(textEditor, row)

        textEditor.setIndentationForBufferRow(row, levels.current)
        textEditor.setIndentationForBufferRow(row + 1, levels.next)

    definitionInfo: (textEditor, row) ->
        result = {topLevelRow: row, topLevelText: null, do: false, type: null}

        while row >= 0
            line = result.line = textEditor.getTextInBufferRange [[row, 0], [row+1, 0]]
            result.do = true if !result.do and /\bdo\b/.test(line)
            result.topLevelRow = row--

            if /^module\b/.test line
                result.type = 'module'
                break

            else if /^foreign\b/.test line
                result.type = 'foreign'
                break

            else if /^import\b/.test line
                result.type = 'import'
                break

            else if /^type\b/.test line
                result.type = 'synonym'
                break

            else if /^class\b/.test line
                result.type = 'class'
                break

            else if /^instance\b/.test line
                result.type = 'instance'
                break

            else if /^\b\S+\b\s*(::|∷)/.test line
                result.type = 'type'
                break

            else if /^\s*\b\S+\b\s*=/.test line
                result.type = 'function'
                break

        return result

    indentLevel: (textEditor, row) ->
        currentLevel = textEditor.indentationForBufferRow row

        beforeLine  = textEditor.getTextInBufferRange [[row-1, 0], [row, 0]]
        currentLine = textEditor.getTextInBufferRange [[row, 0], [row+1, 0]]

        levels = {current: currentLevel, next: currentLevel, rules: []}

        defInfo = @definitionInfo(textEditor, row)

        switch defInfo.type
            when 'module'
                if /\bwhere\b/.test currentLine
                    levels.next = 0
                    levels.rules.push 'module:next-of-where'
                else if row == defInfo.topLevelRow
                    levels.next = 1
                    levels.rules.push 'module:where'
                break

            when 'function'
                if row == defInfo.topLevelRow
                    levels.next = textEditor.indentationForBufferRow(defInfo.topLevelRow) + 1
                    levels.rules.push 'function:top'
                    break

                i_where = currentLine.search /\bwhere\b/
                if i_where >= 0
                    tlIndent = textEditor.indentationForBufferRow defInfo.topLevelRow
                    levels.current = tlIndent + 0.5
                    levels.next    = tlIndent + 1
                    levels.rules.push 'function:where'
                    break

                i_if = currentLine.search /\bif\b/
                if i_if >= 0
                    levels.next = i_if / textEditor.getTabLength()
                    levels.rules.push 'function:if'
                    break

            when 'type'
                if defInfo.topLevelRow == row
                    i_double_colon = currentLine.search /(::|∷)/
                    levels.next = i_double_colon / textEditor.getTabLength()
                    levels.rules.push 'type:::'
                    break

            else
                if /\bwhere\b/.test currentLine
                    levels.next += 1
                    levels.rules.push '*:where'
                    break

        console.log "haskell-indent:" + JSON.stringify(levels.rules) +
            " current:" + levels.current + " next:" + levels.next
        return levels
