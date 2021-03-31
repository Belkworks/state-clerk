
# Clerk
*A state manager in MoonScript*  

**Importing with [Neon](https://github.com/Belkworks/NEON)**:
```lua
Store = NEON:github('belkworks', 'clerk')
```

## API

### Definitions

- Mutation: A function that can affect a state. Must be **synchronous**.  
	- Receives the parameters `(state, payload)`
	- Can read or write to `state`
	- May trigger getters to be recalculated

- Action: A function that runs mutations. May be **asynchronous**.
	- Receives the parameters `(store, payload)`
	- Can run other mutations with `store:commit`

- Getter: A function that computes a value based on the state.
	- Receives the parameters `(state, getters)`
	- Result is cached and not recalculated until the state changes
	- Can return a function
	- `getters` is a table containing the store's other getters
	- **Note:** A getter **can not** modify `state` or `getters`!

### Creating a store

To create a **Store**, call `Store` with an options table.  
`Store(scheme) -> Store`  
The `scheme` table has the following keys:  
`state`: The starting state table of the Store (defaults to `{}`)  
`mutations`: A table containing named functions  
`actions`: Like `mutations`, a table containing named functions  
`getters`: Like `mutations`, a table containing named functions
```lua
store = Store({
    state = { counter = 1 },
    mutations = {
        increment = function(state, payload)
            state.counter = state.counter + payload.amount or 1
        end
    }
})
```

### Store Operations

**commit**: `store:commit(mutation, payload) -> value?`  
Alternative call: `store:commit({type = [mutation], ...}) -> value?`  
Runs the mutation specified by `mutation` with the parameter `payload`  
```lua
store:commit('increment', {
    amount = 1
})

-- same as
store:commit({
    type = 'increment',
    amount = 1
})
```

**dispatch**: `store:dispatch(action, payload) -> nil`  
Alternative call: `store:dispatch({type = [action], ...}) -> value?`  
Runs the action specified by `action` with the parameter `payload`  
```lua
store:dispatch('doSomething', {
    amount = 1
})
```

### Reading the state/getters

To read the state, use the `state` property of the Store.
```lua
print(store.state.counter)
```

To read a getter, index the `getters` table of the Store.
```lua
print(store.getters.doubled)
```

### Modifying the state

All state modifications should be done through a mutation.  
While it is possible to modify the state manually, this will not recalculate getters.
```lua
store.state.test = 123 -- don't do this
```

### Understanding Getters

When a getter indexes the `state` or `getters` parameters, it is tracked internally.  
Getters are only recalculated when a dependency of theirs is changed.  
This means that a getter defined as such would not behave as expected:
```lua
store = Store({
    getters = {
        time = function() return os.time() end
    }
})

earlier = state.getters.time
-- some time later
later = state.getters.time
print(earlier == later) -- true, because time was not recalculated
```

To force recalculation of a getter, use the **runGetter** function.  
**runGetter**: `store:runGetter(name) -> value?`
```lua
now = state:runGetter('time') -- returns and caches the current time
```

To force recalculation of all getters that depend on a key, use the **updateKey** function.
**updateKey**: `store:updateKey(name) -> nil`
```lua
state:updateKey('counter') -- recalculates all getters that depend on counter
```

A getter can take user input by returning a function.
```lua
canAfford = function(state)
    return function(amount)
        return state.amount >= amount
    end
end
```



## Full Example
```lua
store = Store({
    state = {
        counter = 0
    },
    mutations = {
        increment = function(state, payload)
            state.counter = state.counter + payload.amount or 1
        end,
        set = function(state, payload)
            state.commit = payload.value
        end
    },
    actions = {
        doSomething = function(store, payload)
            -- do some asynchronous work
            store:commit('increment', {amount = 2})
        end
    },
    getters = {
        doubled = function(state) return state.counter * 2 end,
        nextDoubled = function(state, getters) return getters.doubled + 1 end
    }
})

store:commit('increment', {
    amount = 1
})

-- same as
store:commit({
    type = 'increment',
    amount = 1
})

print(store.state.counter) -- 2
print(store.getters.nextDoubled) -- 5
```
