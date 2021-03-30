-- clerk.moon
-- SFZILabs 2021

copy = (T) -> {i, v for i, v in pairs T}
defaults = (Object, Props) ->
    Object[i] = v for i, v in pairs Props when nil == Object[i]

class Store
    new: (@Options = {}) =>
        defaults @Options,
            state: {}
            mutations: {}
            actions: {}
            getters: {}

        @state = @Options.state
        @setGetter K, V for K, V in pairs @Options.getters
        @getValue K for K in pairs @Options.getters

    runGetter: (Name) =>
        G = @getterTable[Name]
        if G
            if G.Running
                error 'getter '..Name..' references itself!'

            G.Running = true
            G.Value = G.Runner G.StateReader, G.GetterReader
            G.Running = false
            G.Calculated = true
            return G.Value
        else error 'unknown getter: '..G

    updateValue: (Key) =>
        return unless @getterTable
        Updated = {}
        for Name, G in pairs @getterTable
            continue if Updated[Name]
            RecalculateGetters = false
            for D in pairs G.Dependencies.Keys
                if D == Key
                    Old = @getValue Name
                    New = @runGetter Name
                    Updated[Name] = true
                    RecalculateGetters = Old != New
                    break

            if RecalculateGetters
                for Dependent, G in pairs @getterTable
                    print Dependent, Updated[Dependent]
                    continue if Updated[Dependent]
                    if G.Dependencies.Getters[Name]
                        @runGetter Dependent
                        Updated[Name] = true

    getValue: (Name) =>
        G = @getterTable[Name]
        if G
            return G.Value if G.Calculated
            @runGetter Name
        else error 'unknown getter: '..Name

    createGetterTable: =>
        @getterTable = {}

        keys = {}
        setmetatable keys,
            __index: (G, Name) ->
                if @getterTable[Name]
                    @getValue Name
                else error 'unknown getter: '..Name

            __newindex: (G, Getter, Name) ->
                assert type(Name) == 'function', 'can only assign functions to .getters!'
                @setGetter Getter, Name
                rawset keys, Name, 1

        @getters = keys

    setGetter: (Key, Runner) =>
        unless @getterTable
            @createGetterTable!

        G = {
            :Runner
            Dependencies: Keys: {}, Getters: {}
        }

        G.StateReader = setmetatable {},
            __index: (R, K) ->
                G.Dependencies.Keys[K] = true
                @state[K]

            __newindex: (R, K) -> error 'getter tried to set state key '..K

        G.GetterReader = setmetatable {},
            __index: (R, K) ->
                G.Dependencies.Getters[K] = true
                @getValue K

            __newindex: (R, K) -> error 'getter tried to set getter key '..K

        @getterTable[Key] = G

    resolveData: (Name, Object) =>
        if 'table' == type Name
            if Name.type
                T = Name.type
                return T, with copy Name
                    .type = nil
            error 'couldnt resolve mutation/action (no .type)'
        Name, Object

    commit: (Mutation, Payload) =>
        Mutation, Payload = @resolveData Mutation, Payload
        M = @Options.mutations[Mutation]
        error 'failed to find mutation: '..Mutation unless M

        stateTracker = setmetatable {},
            __index: @state -- (R, K) -> @state[K]
            __newindex: (R, K, V) ->
                @state[K] = V
                @updateValue K

        M stateTracker, Payload

    dispatch: (Action, Payload) =>
        Action, Payload = @resolveData Action, Payload
        A = @Options.actions[Action]
        error 'failed to find action: '..Action unless A
        spawn -> A Payload
