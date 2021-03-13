--[[
    Filename:    click.lua
    Author:      chenhailong
    Datetime:    2018-11-30 20:25:51
    Description: Command line interface creation kit.
--]]
local _print = _G.print

local function classMeta(cls)
    return {
        __metatable = "private",
        __call = function (cls, ...)
            local obj = setmetatable({__class__ = cls,}, {
                __index = cls,
            })
            obj:initialize(...)
            return obj
        end,
        __index = function (t, k)
            local super = rawget(cls, "__super__")
            return super and super[k]
        end,
    }
end

--- @class click.Object
local Object = {__name__ = "Object"}
Object = setmetatable(Object, classMeta(Object))

function Object:initialize()
end

function Object:subclass(name)
    local cls = {
        __name__ = name,
        __super__ = self,
    }
    return setmetatable(cls, classMeta(cls))
end

local function class(name, superClass)
    return (superClass or Object):subclass(name)
end

--[[
function Object:super()
    local info = debug.getinfo(2, "nf")
    local name, caller = info.name, info.func
    local cls = self.__class__
    while cls~=nil do
        if rawget(cls, name)==caller then
            return cls.__super__
        end
        cls = cls.__super__
    end
    return nil
end
--]]


--------------------------------------------------------------------------------
--- options parser

local OPT_ERROR_INVALID_OPTION = "INVALID_OPTION"
local OPT_ERROR_MISSING_OPTION = "MISSING_OPTION"
local OPT_ERROR_INADEQUATE_ARGS = "INADEQUATE_ARGS"


--- @class click.OptionConfig
--- @field 1 string @ Alias for `opt` field.
--- @field opt string @ The option specification like these:
---             "-v", "-v, --version", "-s, --shout / --no-shout", "--count <int>"
---             "/v", "/v, /version", "/s, /shout ; /no-shout", "/count:<int>"
--- @field name string @ [Optional] The variable name for the option value.
--- @field is_flag boolean @ [Optional] Whether this option is a boolean flag.
---             If option names in `opt` field are separated by "/" (or ";" for DOS style options),
---             this field will be ignored and the option will always be treated as a boolean flag.
--- @field required boolean @ [Optional] Whether this option is required.
--- @field multiple boolean @ [Optional] Whether this option can be provided multiple times.
--- @field nargs integer @ [Optional] The number of option arguments. Default value is 1.
--- @field default @ [Optional] The default value of this option.
--- @field callback function @ [Optional] A callback that executes after the option is handled.
--- @field help string @ [Optional] The description of this option displayed in the help page.
--- @field metavar string @ [Optional] Used for changing the meta variable in the help page.


--- @class click.ArgumentConfig
--- @field name string @ [Optional] The variable name for the argument value.
--- @field nargs integer|integer[] @ [Optional] The number of arguments. Default value is 1.
---             If it is set to -1, then an unlimited number of arguments is accepted.
---             If it is an array, then the number of arguments is limited in [nargs[1], nargs[2]]
--- @field help string @ [Optional] The description of this argument displayed in the help page.
--- @field metavar string @ [Optional] Used for changing the meta variable in the help page.


--- @class click.OptionsParserConfig
--- @field options_metavar string @ [Optional] Used for changing the meta variable
---             for options in the help page.
--- @field options click.OptionConfig[] @ [Optional] Configurations for all options.
--- @field arguments_metavar string @ [Optional]  Used for changing the meta variable
---             for arguments in the help page.
--- @field arguments click.ArgumentConfig[] @ [Optional] Configurations for arguments.


--- @class click.OptionsParser
local OptionsParser = class("OptionsParser")

--- @desc Constructor of OptionsParser.
--- @param config click.OptionsParserConfig @ Configurations for the parser.
function OptionsParser:initialize(config)
    OptionsParser.__super__.initialize(self)

    self._optionsConfig = {}
    local optionsConfig = config.options
    if optionsConfig~=nil then
        for i, optCfg in ipairs(optionsConfig) do
            self._optionsConfig[i] = self:_parseOptConfig(optCfg)
        end
        self._optionsMetavar = config.options_metavar or "[OPTIONS]"
    else
        self._optionsMetavar = config.options_metavar or ""
    end

    self._argsConfig = {}
    local argsConfig = config.arguments
    if argsConfig~=nil then
        local metavars = argsConfig.metavar==nil and {} or nil
        local minFollows = 0
        for i = #argsConfig, 1, -1 do
            local arg = self:_parseArgConfig(argsConfig[i])
            arg.min_follows = minFollows
            minFollows = minFollows + arg.nargs_min
            self._argsConfig[i] = arg
            if metavars~=nil and arg.metavar~="" then
                -- metavars[#metavars + 1] = arg.metavar
                table.insert(metavars, 1, arg.metavar)
            end
        end
        self._argumentsMetavar = config.arguments_metavar or table.concat(metavars, " ")
    else
        self._argumentsMetavar = config.arguments_metavar or ""
    end
end

--- @desc Append an extra option config.
--- @param optionConfig click.OptionConfig @ The extra option config.
function OptionsParser:appendOption(optionConfig)
    local optionsConfig = self._optionsConfig
    optionsConfig[#optionsConfig + 1] = self:_parseOptConfig(optionConfig)
end

--- #private
function OptionsParser:_parseOptConfig(optCfg)
    local optSpec = optCfg.opt or optCfg[1]
    assert(type(optSpec)=="string", "Invalid option specification")
    local isWindowsStyle = optSpec:sub(1, 1)=="/"
    local switchSeparator = isWindowsStyle and ";" or "/"
    local name = optCfg.name
    local is_flag = optCfg.is_flag
    local ssp = optSpec:find(switchSeparator) -- switch separator position
    if ssp~=nil then is_flag = true end
    local opts, opts_on, opts_off
    local hasMetavarsInSpec = false
    if is_flag then
        if ssp~=nil then
            opts_on, opts_off = optSpec:sub(1, ssp-1), optSpec:sub(ssp+1)
        else
            opts_on, opts_off = optSpec, ""
        end
        opts_on, name = self:_parseOptConfigNames(opts_on, name)
        opts_off, name = self:_parseOptConfigNames(opts_off, name)
    else
        opts, name, hasMetavarsInSpec = self:_parseOptConfigNames(optSpec, name)
    end

    local finalConfig = {
        name = name,
        opt = optSpec,
        is_flag = is_flag,
        opts = opts,
        opts_on = opts_on,
        opts_off = opts_off,
        required = optCfg.required and true or false,
        help = optCfg.help or nil,
        callback = optCfg.callback,
    }
    if is_flag then
        finalConfig.nargs = 0
        if optCfg.default then
            finalConfig.default = true
        end
        finalConfig.metavar = ""
    else
        assert(optCfg.nargs==nil or optCfg.nargs>0, "Option CANNOT have nargs <= 0")
        finalConfig.nargs = optCfg.nargs or 1
        finalConfig.default = optCfg.default
        if hasMetavarsInSpec then
            finalConfig.metavar = ""
        else
            if optCfg.metavar~=nil then
                finalConfig.metavar = optCfg.metavar
            else
                finalConfig.metavar = finalConfig.nargs==1 and "<VALUE>" or "<VALUES...>"
            end
        end
    end
    if optCfg.multiple then
        finalConfig.multiple = true
        assert(finalConfig.default==nil or type(finalConfig.default)=="table",
               "Default value for multiple option MUST be an array")
    else
        finalConfig.multiple = false
    end
    return finalConfig
end

--- #private
function OptionsParser:_parseOptConfigNames(optSpec, varName)
    local optionPattern = "%s*([%-%/]+)([%w_%-]+)"
    local skipPattern = "^%s*([^,]*),*"
    local opts = {}
    local tmpName = varName==nil and "" or nil
    local s, e, prefix, name = optSpec:find(optionPattern)
    local hasMetavars = false
    while prefix~=nil do
        local optName = prefix .. name
        opts[#opts + 1] = optName
        opts[optName] = true
        if tmpName~=nil and tmpName:len()<name:len() then
            tmpName = name
        end
        local metavar
        s, e, metavar = optSpec:find(skipPattern, e+1)
        if metavar~=nil and metavar~="" then hasMetavars = true end
        s, e, prefix, name, extra = optSpec:find(optionPattern, e+1)
    end
    return opts, tmpName or varName, hasMetavars
end

--- #private
function OptionsParser:_parseArgConfig(argCfg)
    local name = argCfg.name
    assert(name~=nil, "Argument must have a name")
    local nargs = argCfg.nargs or 1
    local nargs_min, nargs_max
    local nargsType = type(nargs)
    assert(nargsType=="number" or nargsType=="table",
        "Argument nargs MUST be an integer or an integer array")
    if nargsType=="number" then
        nargs_min, nargs_max = nargs, nargs
    elseif nargsType=="table" then
        nargs_min, nargs_max = nargs[1] or 0, nargs[2] or -1
    else
        nargs_min, nargs_max = 1, 1
    end
    if nargs_min<0 then
        nargs_min = 0
    end
    local metavar = argCfg.metavar
    if metavar==nil then
        metavar = string.upper(name)
        if nargs_max~=1 then metavar = metavar .. "..." end
        if nargs_min==0 then metavar = "[" .. metavar .. "]" end
    end
    local finalConfig = {
        name = name,
        nargs_min = nargs_min,
        nargs_max = nargs_max,
        metavar = metavar,
        help = argCfg.help or nil,
    }
    return finalConfig
end

function OptionsParser:getOptionsMetavar()
    return self._optionsMetavar
end

function OptionsParser:getOptionsDetailMetavars()
    local lines = {}
    for i, opt in ipairs(self._optionsConfig) do
        local metavar = opt.opt .. " " .. opt.metavar
        lines[#lines + 1] = {metavar, opt.help or ""}
    end
    return lines
end

function OptionsParser:getArgumentsMetavar()
    return self._argumentsMetavar
end

function OptionsParser:getArgumentsDetailMetavars()
    local lines = {}
    for i, arg in ipairs(self._argsConfig) do
        if arg.help~=nil then
            lines[#lines + 1] = {arg.metavar, arg.help}
        end
    end
    return lines
end

--- @param tokens string[] @ Array of argument tokens.
--- @param index integer @ Index of next argument token.
--- @return table @ The context for parsing options.
function OptionsParser:startParsing(tokens, index)
    local context = {}

    context.optionValues = {}
    context.arguments = {}

    -- fill default option values
    local optionValues = context.optionValues
    local multipleOptionDefaults = {}
    context._multipleOptionDefaults = multipleOptionDefaults
    for i, opt in ipairs(self._optionsConfig) do
        if opt.multiple then
            local valueArray = {}
            if opt.default~=nil and #opt.default>0 then
                for i, v in ipairs(opt.default) do valueArray[i] = v end
                multipleOptionDefaults[valueArray] = true
            end
            optionValues[opt.name] = valueArray
        else
            optionValues[opt.name] = opt.default
        end
    end

    context.finishOnError = true
    context.errors = {}
    context.error = nil -- first error
    context.lastError = nil -- last error
    function context:appendError(err)
        if err==nil then return end
        self.errors[#self.errors + 1] = err
        if self.error==nil then self.error = err end
        self.lastError = err
        if self.finishOnError then
            self.finished = true
        end
    end

    function context:exit(exitCode)
        self.finished = true
        if self.exitCode==nil then
            if type(exitCode)=="number" then
                self.exitCode = exitCode
            else
                self.exitCode = (exitCode==nil or exitCode) and 0 or -1
            end
        end
    end

    return context
end

--- @param context table @ The context returned by `startParsing()`.
--- @return boolean @ Indicate whether the parsing is success.
function OptionsParser:finishParsing(context)
    if context.finished then
        return context.error~=nil
    end
    local optionValues = context.optionValues
    for i, opt in ipairs(self._optionsConfig) do
        local name = opt.name
        local value = optionValues[name]
        if opt.required and (value==nil or (opt.multiple and #value==0)) then
            context:appendError({
                                    type = OPT_ERROR_MISSING_OPTION,
                                    opt = opt,
                                })
            if context.finished then
                break
            end
        end
    end
    context.finished = true
    return context.error~=nil
end

--- @param context table @ The context returned by `startParsing()`.
--- @param tokens string[] @ Array of argument tokens.
--- @param index integer @ Index of next argument token.
--- @return integer, string, any @ Next token index, option name and value.
---             If next token is not an option, the name and value will be nil.
function OptionsParser:parseNextOption(context, tokens, index)
    if context.finished then
        return index, nil, nil
    end
    local optName = tokens[index]
    local prefix = optName and optName:sub(1, 1)
    if prefix~="-" and prefix~="/" then
        return index, nil, nil
    end
    index = index + 1

    if optName=="--" then
        -- Treat following option like strings as arguments.
        return index, nil, nil
    end

    local firstArgument
    local sep = optName:find("[=:]")
    if sep~=nil then
        firstArgument = optName:sub(sep+1)
        optName = optName:sub(1, sep-1)
    end

    local matched, value
    for i, opt in ipairs(self._optionsConfig) do
        if opt.opts then
            if opt.opts[optName] then
                matched = opt
                local args
                if firstArgument==nil then
                    args, index = self:_parseArguments(tokens, index, opt.nargs)
                else
                    args, index = self:_parseArguments(tokens, index, opt.nargs-1)
                    table.insert(args, 1, firstArgument)
                end
                if opt.nargs==1 then
                    value = args[1]
                else
                    value = args
                end
                if #args<opt.nargs then
                    context:appendError({
                                            type = OPT_ERROR_INADEQUATE_ARGS,
                                            opt = opt,
                                            optName = optName,
                                            args = args,
                                        })
                end
                break
            end
        else
            if opt.opts_on[optName] then
                matched, value = opt, true
                break
            end
            if opt.opts_off[optName] then
                matched, value = opt, false
                break
            end
        end
    end
    if matched==nil then
        context:appendError({
                                type = OPT_ERROR_INVALID_OPTION,
                                optName = optName,
                            })
        return index, nil, nil
    else
        local name = matched.name
        if matched.multiple then
            local valueArray = context.optionValues[name]
            if valueArray==nil or context._multipleOptionDefaults[valueArray] then
                context.optionValues[name] = { value, }
            else
                valueArray[#valueArray + 1] = value
            end
        else
            -- XXX If the value is already exists, overwrite it.
            context.optionValues[name] = value
        end
        if matched.callback~=nil then
            matched.callback(context, name, value)
        end
        return index, name, value
    end
end

function OptionsParser:_parseArguments(tokens, index, nargs)
    local values, ii = {}, 1
    while ii<=nargs do
        local tok = tokens[index]
        if tok==nil then break end
        index = index + 1
        values[ii], ii = tok, ii + 1
    end
    return values, index
end

--- @param context table @ The context returned by `startParsing()`.
--- @param tokens string[] @ Array of argument tokens.
--- @param index integer @ Index of next argument token.
--- @return integer @ Next token index.
function OptionsParser:parseArguments(context, tokens, index)
    if context.finished then
        return index
    end
    local arguments = context.arguments
    for i, arg in ipairs(self._argsConfig) do
        local nargs, values
        nargs = arg.nargs_max
        if nargs<0 then
            nargs = #tokens - index + 1 - arg.min_follows
        end
        values, index = self:_parseArguments(tokens, index, nargs)
        if arg.nargs_max==1 then
            arguments[arg.name] = values[1]
        else
            arguments[arg.name] = values
        end
        if #values<arg.nargs_min then
            context:appendError({
                                    type = OPT_ERROR_INADEQUATE_ARGS,
                                    arg = arg,
                                    args = values,
                                })
            break
        end
    end
    return index
end

function OptionsParser:errorToString(error)
    if not error then
        return nil
    end
    if error.type == OPT_ERROR_INVALID_OPTION then
        return string.format("No such option: \"%s\"", error.optName)
    elseif error.type == OPT_ERROR_MISSING_OPTION then
        local expected
        local opt = error.opt
        if opt.opts~=nil then
            expected = table.concat(opt.opts, "\" / \"")
        else
            local opts = {}
            for _, name in ipairs(opt.opts_on) do opts[#opts + 1] = name end
            for _, name in ipairs(opt.opts_on) do opts[#opts + 1] = name end
            expected = table.concat(opts, "\" / \"")
        end
        return string.format("Missing option: \"%s\"", expected)
    elseif error.type == OPT_ERROR_INADEQUATE_ARGS then
        if error.opt~=nil then
            local nargs = error.opt.nargs
            return string.format("\"%s\" option requires %d %s",
                                 error.optName,
                                 nargs,
                                 nargs>1 and "arguments" or "argument"
            )
        end
        if error.arg~=nil then
            local args = error.args
            if args==nil or #args==0 then
                return string.format("Missing argument \"%s\"", error.arg.metavar)
            else
                local nargs = error.arg.nargs_min
                return string.format("Argument \"%s\" requires at least %d %s",
                                     error.arg.metavar,
                                     nargs,
                                     nargs>1 and "arguments" or "argument"
                )
            end
        end
    end
    return string.format("Parsing option error: %s", error.type)
end

--- @return integer|nil, ... @ The first value is exit code.
function OptionsParser:parse(args, command, proc)
    local index, opt, value = args.optidx, nil, nil
    local context = self:startParsing(args, index)
    context.command = command
    context.proc = proc
    local optionValues = context.optionValues
    while true do
        index, opt, value = self:parseNextOption(context, args, index)
        if opt==nil then break end
        if context.finished then break end
    end
    index = self:parseArguments(context, args, index)
    self:finishParsing(context)
    args.optidx = index

    if context.exitCode~=nil then
        return context.exitCode
    end

    if context.error~=nil then
        return -1, context.error
    end

    return nil, context.optionValues, context.arguments
end


--------------------------------------------------------------------------------
--- command classes

local function isFailed(exitCode)
    return exitCode~=nil and exitCode~=true and exitCode~=0
end


--- @class click.HelpConfig : click.OptionConfig
--- @field disabled boolean @ [Optional] Whether disable the help option. Default value is false.


--- @class click.BaseCommandConfig
--- @field desc string @ [Optional] Description of the command.
--- @field options_metavar string @ [Optional] Used for changing the meta variable
---             for options in the help page.
--- @field options click.OptionConfig[] @ [Optional] Configurations for all options.
--- @field help_option click.HelpConfig @ [Optional] The configuration for help option.
--- @field arguments_metavar string @ [Optional]  Used for changing the meta variable
---             for arguments in the help page.
--- @field arguments click.ArgumentConfig[] @ [Optional] Configurations for arguments.


--- @class click.BaseCommand
local BaseCommand = class("BaseCommand")

--- @desc Constructor of BaseCommand.
--- @param cfg click.BaseCommandConfig @ Configuration for the command.
function BaseCommand:initialize(cfg)
    BaseCommand.__super__.initialize(self)
    self._description = cfg and cfg.desc or string.format("<%s>", self.__class__.__name__)
    local optionsConfig = cfg and cfg.options or {}
    local optionsMetavar = cfg and cfg.options_metavar
    if optionsMetavar==nil then
        optionsMetavar = #optionsConfig > 0 and "[OPTIONS]" or ""
    end
    -- optionsConfig[#optionsConfig + 1] = self:_makeHelpOption(cfg)
    local argsConfig = cfg and cfg.arguments
    local argsMetavar = cfg and cfg.arguments_metavar
    self._optionsParser = OptionsParser({
        options_metavar = optionsMetavar,
        options = optionsConfig,
        arguments_metavar = argsMetavar,
        arguments = argsConfig,
    })
    self:_setupHelpOption(self._optionsParser, cfg)
    self._ignoreExtraArguments = false
end

function BaseCommand:_setupHelpOption(optionsParser, cfg)
    local helpOption = cfg and cfg.help_option or { "--help", }
    if helpOption.disabled then
        return
    end
    if helpOption==(cfg and cfg.help_option) then
        helpOption = {}
        for k, v in pairs(cfg.help_option) do helpOption[k] = v end
    end
    helpOption.name = "$HELP"
    helpOption.is_flag = true
    if helpOption.help==nil then
        helpOption.help = "Show this message and exit."
    end
    if helpOption.callback==nil then
        helpOption.callback = function (ctx, name, value)
            ctx.command:help(ctx.proc)
            ctx:exit(0)
        end
    end
    optionsParser:appendOption(helpOption)
end

function BaseCommand:printf(fmt, ...)
    return _print(string.format(fmt, ...))
end

function BaseCommand:description()
    return self._description or ""
end

function BaseCommand:usagePattern(proc)
    local parts = { proc, }
    local metavar = self._optionsParser:getOptionsMetavar()
    if metavar~=nil and metavar~="" then parts[#parts + 1] = metavar end
    local metavar = self._optionsParser:getArgumentsMetavar()
    if metavar~=nil and metavar~="" then parts[#parts + 1] = metavar end
    return table.concat(parts, " ")
end

function BaseCommand:usage(proc, showDescription)
    self:printf("Usage: %s", self:usagePattern(proc))
    if showDescription then
        local desc = self:description()
        if desc~=nil and desc~="" then
            self:printf("\n%s%s", "  ", desc)
        end
    end
end

function BaseCommand:help(proc)
    self:usage(proc, true)
    local indents = "  "
    local options = self._optionsParser:getOptionsDetailMetavars()
    if #options>0 then
        self:printHelpSection("\nOptions:", options, indents)
    end
    local arguments = self._optionsParser:getArgumentsDetailMetavars()
    if #arguments>0 then
        self:printHelpSection("\nArguments:", arguments, indents)
    end
end

function BaseCommand:printHelpSection(title, lines, indents)
    if lines==nil then
        return
    end

    -- calculate the maximum width of head part
    local width = 10
    for i, line in ipairs(lines) do
        local len = line[1]:len()
        if len>width then
            width = 4*math.floor((len+5)/4) - 2
        end
    end
    if width>30 then width = 30 end

    self:printf("%s", title)
    local fmt = "%s%-" .. width .. "s  %s"
    for i, line in ipairs(lines) do
        local head, desc = line[1], line[2]
        if head:len()>width then
            self:printf("%s%s", indents, head)
            self:printf(fmt, indents, "", desc)
        else
            self:printf(fmt, indents, head, desc)
        end
    end
end

function BaseCommand:execute(proc, args)
end

function BaseCommand:getExtraArguments()
    return self._extraArgs
end

function BaseCommand:ignoreExtraArguments(enabled)
    self._ignoreExtraArguments = enabled
end

function BaseCommand:checkExtraArguments(proc)
    if self._ignoreExtraArguments then
        return true
    end
    local args = self._extraArgs
    if args==nil or #args==0 then
        return true
    end
    self:usage(proc)
    self:printf("\n[error] Got unexpected extra %s (%s)",
                #args>1 and "arguments" or "argument",
                table.concat(args, " "))
    return false
end

--- @return integer|nil, ...
function BaseCommand:parseOptions(proc, args)
    local optionsParser = self._optionsParser
    if args==nil then
        args = self._extraArgs
    end

    args.optidx = 1
    local exitCode, extra1, extra2 = optionsParser:parse(args, self, proc)

    if args.optidx>1 then
        self._extraArgs = self:shiftArgs(args.optidx-1, args)
    else
        self._extraArgs = args
    end

    if exitCode~=nil then
        if exitCode==-1 and extra1~=nil then
            self:usage(proc)
            self:printf("\n[error] %s", optionsParser:errorToString(extra1))
        end
        return exitCode
    else
        return nil, extra1, extra2
    end
end

function BaseCommand:shiftArgs(n, args)
    if args==nil then
        args = self._extraArgs
    end
    local newArgs
    if n>0 and args~=nil then
        newArgs = {}
        for i = 1, #args-n do
            newArgs[i] = args[n+i]
        end
    else
        newArgs = args
    end
    self._extraArgs = newArgs
    return newArgs
end

function BaseCommand:setContext(context)
    self._context = context
end

function BaseCommand:getContext(context)
    return self._context
end


--- @class click.CommandGroupConfig : click.BaseCommandConfig
--- @field chain boolean @ [Optional] Whether it is allowed to invoke more than one
---             subcommand in one go.
--- @field entry_func function @ [Optional] The entry function of this command.
--- @field subcommand_metavar string @ [Optional] Used for changing the meta variable
---             for subcommand in the help page.


--- @class click.CommandGroup
local CommandGroup = class("CommandGroup", BaseCommand)

--- @desc Constructor of CommandGroup.
--- @param cfg click.CommandGroupConfig @ Configuration for the command.
function CommandGroup:initialize(cfg)
    CommandGroup.__super__.initialize(self, cfg)
    self._subCommands = {}
    self._entryFunction = cfg.entry_func
    self._chain = cfg and cfg.chain and true or false
    self._subCommandMetavar = cfg and cfg.subcommand_metavar
    if self._subCommandMetavar==nil then
        if self._chain then
            self._subCommandMetavar = "COMMAND1 [ARGS]... [COMMAND2 [ARGS]...]..."
        else
            self._subCommandMetavar = "COMMAND [ARGS]..."
        end
    end
end

function CommandGroup:usagePattern(proc)
    local usage = CommandGroup.__super__.usagePattern(self, proc)
    return usage .. " " .. self._subCommandMetavar
end

function CommandGroup:help(proc)
    CommandGroup.__super__.help(self, proc)
    local subcommands = {}
    for name, cmd in pairs(self._subCommands) do
        subcommands[#subcommands + 1] = { name, cmd:description() }
    end
    table.sort(subcommands, function (a, b) return a[1] < b[1] end)
    self:printHelpSection("\nCommands:", subcommands, "  ")
end

function CommandGroup:execute(proc, args)
    local exitCode, options, arguments = self:parseOptions(proc, args)
    if exitCode~=nil then
        return exitCode
    end

    if self._entryFunction~=nil then
        exitCode = self._entryFunction(self, options, arguments)
        if exitCode~=nil then
            return exitCode
        end
    end

    args = self:getExtraArguments()
    local cmdName = args and args[1]
    if cmdName==nil then
        if #options==0 and #arguments==0 then
            self:help(proc)
            return 0
        end
        self:usage(proc)
        self:printf("\n[error] Missing command.")
        return -1
    end

    if not self._chain then
        local cmd = self._subCommands[cmdName]
        if cmd==nil then
            self:usage(proc)
            self:printf("\n[error] No such command: \"%s\"", cmdName)
            return -1
        end
        cmd:setContext(self:getContext())
        cmd:ignoreExtraArguments(self._ignoreExtraArguments)
        local subProc = proc.." "..cmdName
        exitCode = cmd:execute(subProc, self:shiftArgs(1, args))
        self._extraArgs = cmd:getExtraArguments()
        if isFailed(exitCode) then
            return exitCode
        end
    else
        while cmdName~=nil do
            local cmd = self._subCommands[cmdName]
            if cmd==nil then
                self:usage(proc)
                self:printf("\n[error] No such command: \"%s\"", cmdName)
                return -1
            end
            cmd:setContext(self:getContext())
            cmd:ignoreExtraArguments(true)
            local subProc = proc.." "..cmdName
            args = self:shiftArgs(1, args)
            exitCode = cmd:execute(subProc, args)
            if isFailed(exitCode) then
                return exitCode
            end
            args = cmd:getExtraArguments()
            self._extraArgs = args
            cmdName = args and args[1]
        end
    end

    if not self:checkExtraArguments(proc) then
        return -1
    end
    return 0
end

function CommandGroup:addCommand(name, command)
    assert(command~=nil)
    self._subCommands[name] = command
end


--- @class click.FunctionCommand
local FunctionCommand = class("FunctionCommand", BaseCommand)

--- @class click.FunctionCommandConfig : click.BaseCommandConfig
--- @field entry_func function @ The entry function of this command.


--- @desc Constructor of FunctionCommand.
--- @param cfg click.FunctionCommandConfig @ Configuration for the command.
function FunctionCommand:initialize(cfg)
    FunctionCommand.__super__.initialize(self, cfg)
    assert(cfg~=nil, "`cfg` is required")
    self._entryFunction = cfg.entry_func
    assert(self._entryFunction~=nil, "Entry function CANNOT be empty.")
end

function FunctionCommand:execute(proc, args)
    local exitCode, options, arguments = self:parseOptions(proc, args)
    if exitCode~=nil then
        return exitCode
    end
    if not self:checkExtraArguments(proc) then
        return -1
    end
    return self._entryFunction(self, options, arguments)
end


--- @class click.ExecuteFileCommandConfig : click.BaseCommandConfig
--- @field entry_file string @ The path of the target file.


--- @class click.ExecuteFileCommand
local ExecuteFileCommand = class("ExecuteFileCommand", BaseCommand)

--- @desc Constructor of ExecuteFileCommand.
--- @param cfg click.ExecuteFileCommandConfig @ Configuration for the command.
function ExecuteFileCommand:initialize(cfg)
    ExecuteFileCommand.__super__.initialize(self, cfg)
    assert(cfg~=nil, "`cfg` is required")
    local filename = cfg.entry_file
    self._fileName = filename
    self._description = cfg.desc or string.format("Execute file '%s'", filename)
end

function ExecuteFileCommand:loadFileWithEnv(filename, env)
    local luaVersion = _G._VERSION
    if luaVersion == "Lua 5.1" then
        local module, error = loadfile(self._fileName)
        if module~=nil then
            module = setfenv(module, env)
        end
        return module, error
    elseif luaVersion == "Lua 5.2" or luaVersion == "Lua 5.3"  then
        return loadfile(self._fileName, "bt", env)
    end
end

function ExecuteFileCommand:execute(proc, args)
    local exitCode, options, arguments = self:parseOptions(proc, args)
    if exitCode~=nil then
        return exitCode
    end
    if not self:checkExtraArguments(proc) then
        return -1
    end
    local env = setmetatable({
                                 _COMMAND = self,
                                 _OPTIONS = options,
                                 _ARGUMENTS = arguments,
                             },
                             {__index = _G})
    local module, error = self:loadFileWithEnv(self._fileName, env)
    if module~=nil then
        local extraArgs = self:getExtraArguments()
        return module(proc, unpack(args, 1, #args-#extraArgs))
    else
        self:printf("Failed to load file:\n%s", error)
        return -1
    end
end


--------------------------------------------------------------------------------
--- util functions

--- @desc Get the current module name.
local function __name__()
    if debug.getinfo(4, "n")==nil then
        return "__main__" -- main chunk
    else
        --local n, v = debug.getlocal(3, 1)
        --if n=="(*temporary)" then return v end
        local info = debug.getinfo(2, "nS")
        if info.what=="main" then
            local name = info.short_src
            name = name:gsub("^%./", "")
                       :gsub("%.[a-zA-Z0-9_-]+$", "")
                       :gsub("/", ".")
            return "[chunk] " .. name
        elseif info.what=="Lua" then
            return "[function] " .. (info.name or "(*anonymous)")
        else
            return info.what -- "[C]"
        end
    end
end

local function procName(args)
    local filename = args[0]
    if filename==nil then
        return "lua " .. debug.getinfo(3, "S").short_src
    else
        local i = -1
        while args[i] do i = i - 1 end
        return args[i+1] .. " " .. filename
    end
end

--- @desc Execute the command.
--- @param command click.BaseCommand @ The command object to be executed.
--- @param proc string @ The name of the procedure.
--- @param args string[] @ The arguments array.
local function exec(command, proc, args)
    local context = {}
    command:setContext(context)
    command:ignoreExtraArguments(false)
    return command:execute(proc~="" and proc or procName(args), args)
end

--- @desc Execute the command and exit the program.
--- @param command click.BaseCommand @ The command object to be executed.
--- @param proc string @ The name of the procedure.
--- @param args string[] @ The arguments array.
local function main(command, proc, args)
    local exitCode = exec(command, proc~="" and proc or procName(args), args)
    if not isFailed(exitCode) then
        exitCode = 0
    elseif type(exitCode)~="number" then
        exitCode = -1
    end
    return os.exit(exitCode)
end

local function setupPrintFunction(printFunc)
    _print = printFunc or _G.print
end

--------------------------------------------------------------------------------
-- export classes and functions
local _M = {}

_M["_VERSION"] = "click 0.2.2"

_M["OptionsParser"] = OptionsParser
_M["BaseCommand"] = BaseCommand
_M["CommandGroup"] = CommandGroup
_M["FunctionCommand"] = FunctionCommand
_M["ExecuteFileCommand"] = ExecuteFileCommand

_M["__name__"] = __name__
_M["exec"] = exec
_M["main"] = main
_M["setupPrintFunction"] = setupPrintFunction

return _M
