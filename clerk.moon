-- clerk.moon
-- SFZILabs 2021

wrap = (F) -> coroutine.wrap(F)!
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

    alwaysUpdate: (Name) =>
        G = @getterTable[Name]
        if G
            G.Always = true
        else error 'unknown getter: '..G

    updateGetterRecursive: (Name, Updated = {}) =>
        return if Updated[Name]
        Old = @getValue Name
        New = @runGetter Name
        return if New == Old -- no need to update

        for Dep, G in pairs @getterTable
            continue if Updated[Dep]
            if G.Dependencies.Getters[Name]
                @runGetter Dep
                Updated[Dep] = true

    updateKey: (Key) =>
        return unless @getterTable
        Updated = {}
        for Name, G in pairs @getterTable
            continue if Updated[Name]

            GetterReadsKey = false 
            for D in pairs G.Dependencies.Keys
                if D == Key
                    GetterReadsKey = true
                    break

            if GetterReadsKey
                @updateGetterRecursive Name, Updated
                Updated[Name] = true

    getValue: (Name) =>
        G = @getterTable[Name]
        if G
            if G.Calculated
                return G.Value unless G.Always

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
            __index: (K) =>
                G.Dependencies.Keys[K] = true
                @state[K]

            __newindex: (K) => error 'getter tried to set state key '..K

        G.GetterReader = setmetatable {},
            __index: (K) =>
                return if K == Key
                G.Dependencies.Getters[K] = true
                @getValue K

            __newindex: (K) => error 'getter tried to set getter key '..K

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
            __newindex: (K, V) =>
                @state[K] = V
                @updateKey K

        M stateTracker, Payload

    dispatch: (Action, Payload) =>
        Action, Payload = @resolveData Action, Payload
        A = @Options.actions[Action]
        error 'failed to find action: '..Action unless A
        wrap -> A @, Payload

        nil
