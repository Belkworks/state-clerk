local copy
copy = function(T)
  local _tbl_0 = { }
  for i, v in pairs(T) do
    _tbl_0[i] = v
  end
  return _tbl_0
end
local defaults
defaults = function(Object, Props)
  for i, v in pairs(Props) do
    if nil == Object[i] then
      Object[i] = v
    end
  end
end
local Store
do
  local _class_0
  local _base_0 = {
    runGetter = function(self, Name)
      local G = self.getterTable[Name]
      if G then
        if G.Running then
          error('getter ' .. Name .. ' references itself!')
        end
        G.Running = true
        G.Value = G.Runner(G.StateReader, G.GetterReader)
        G.Running = false
        G.Calculated = true
        return G.Value
      else
        return error('unknown getter: ' .. G)
      end
    end,
    updateValue = function(self, Key)
      if not (self.getterTable) then
        return 
      end
      local Updated = { }
      for Name, G in pairs(self.getterTable) do
        local _continue_0 = false
        repeat
          if Updated[Name] then
            _continue_0 = true
            break
          end
          local RecalculateGetters = false
          for D in pairs(G.Dependencies.Keys) do
            if D == Key then
              local Old = self:getValue(Name)
              local New = self:runGetter(Name)
              Updated[Name] = true
              RecalculateGetters = Old ~= New
              break
            end
          end
          if RecalculateGetters then
            for Dependent, G in pairs(self.getterTable) do
              local _continue_1 = false
              repeat
                print(Dependent, Updated[Dependent])
                if Updated[Dependent] then
                  _continue_1 = true
                  break
                end
                if G.Dependencies.Getters[Name] then
                  self:runGetter(Dependent)
                  Updated[Name] = true
                end
                _continue_1 = true
              until true
              if not _continue_1 then
                break
              end
            end
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end,
    getValue = function(self, Name)
      local G = self.getterTable[Name]
      if G then
        if G.Calculated then
          return G.Value
        end
        return self:runGetter(Name)
      else
        return error('unknown getter: ' .. Name)
      end
    end,
    createGetterTable = function(self)
      self.getterTable = { }
      local keys = { }
      setmetatable(keys, {
        __index = function(G, Name)
          if self.getterTable[Name] then
            return self:getValue(Name)
          else
            return error('unknown getter: ' .. Name)
          end
        end,
        __newindex = function(G, Getter, Name)
          assert(type(Name) == 'function', 'can only assign functions to .getters!')
          self:setGetter(Getter, Name)
          return rawset(keys, Name, 1)
        end
      })
      self.getters = keys
    end,
    setGetter = function(self, Key, Runner)
      if not (self.getterTable) then
        self:createGetterTable()
      end
      local G = {
        Runner = Runner,
        Dependencies = {
          Keys = { },
          Getters = { }
        }
      }
      G.StateReader = setmetatable({ }, {
        __index = function(R, K)
          G.Dependencies.Keys[K] = true
          return self.state[K]
        end,
        __newindex = function(R, K)
          return error('getter tried to set state key ' .. K)
        end
      })
      G.GetterReader = setmetatable({ }, {
        __index = function(R, K)
          G.Dependencies.Getters[K] = true
          return self:getValue(K)
        end,
        __newindex = function(R, K)
          return error('getter tried to set getter key ' .. K)
        end
      })
      self.getterTable[Key] = G
    end,
    resolveData = function(self, Name, Object)
      if 'table' == type(Name) then
        if Name.type then
          local T = Name.type
          return T, (function()
            do
              local _with_0 = copy(Name)
              _with_0.type = nil
              return _with_0
            end
          end)()
        end
        error('couldnt resolve mutation/action (no .type)')
      end
      return Name, Object
    end,
    commit = function(self, Mutation, Payload)
      Mutation, Payload = self:resolveData(Mutation, Payload)
      local M = self.Options.mutations[Mutation]
      if not (M) then
        error('failed to find mutation: ' .. Mutation)
      end
      local stateTracker = setmetatable({ }, {
        __index = self.state,
        __newindex = function(R, K, V)
          self.state[K] = V
          return self:updateValue(K)
        end
      })
      return M(stateTracker, Payload)
    end,
    dispatch = function(self, Action, Payload)
      Action, Payload = self:resolveData(Action, Payload)
      local A = self.Options.actions[Action]
      if not (A) then
        error('failed to find action: ' .. Action)
      end
      return spawn(function()
        return A(Payload)
      end)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, Options)
      if Options == nil then
        Options = { }
      end
      self.Options = Options
      defaults(self.Options, {
        state = { },
        mutations = { },
        actions = { },
        getters = { }
      })
      self.state = self.Options.state
      for K, V in pairs(self.Options.getters) do
        self:setGetter(K, V)
      end
      for K in pairs(self.Options.getters) do
        self:getValue(K)
      end
    end,
    __base = _base_0,
    __name = "Store"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Store = _class_0
  return _class_0
end
