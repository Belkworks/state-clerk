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
        @createGetter K, V for K, V in pairs @Options.getters

    createGetter: (Key, Runner) =>

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
        M @, @state, Payload

    dispatch: (Action, Payload) =>
        Action, Payload = @resolveData Action, Payload
        A = @Options.actions[Action]
        error 'failed to find action: '..Action unless A
        spawn -> A @, Payload
