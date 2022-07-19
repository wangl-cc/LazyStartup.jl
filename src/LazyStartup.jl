module LazyStartup

import REPL
using Base.Meta: isexpr

export @lazy_startup

mutable struct Startup{F}
    ex::Expr
    evaled::Bool
    pattern::F
end
function Startup(ex::Expr, pattern::F) where {F}
    return Startup{F}(ex, false, pattern)
end
should_eval(ex, s::Startup) = !s.evaled && match_expr(s.pattern, ex)

# :* is a wildcard pattern, which matches anything
match_expr(pattern::Symbol, ex) = pattern === :* || pattern === ex
function match_expr(pattern::Symbol, ex::Expr)
    for arg in ex.args
        match_expr(pattern, arg) && return true
    end
    return false
end
match_expr(pattern::Expr, ex) = false
function match_expr(pattern::Expr, ex::Expr)
    ex_match = false
    if pattern.head === ex.head
        ex_match = true
        for sub_p in pattern.args
            arg_match = false
            for arg in ex.args
                if match_expr(sub_p, arg)
                    arg_match = true
                    break
                end
            end
            if !arg_match
                ex_match = false
                break
            end
        end
    end
    ex_match && return true
    for arg in ex.args
        match_expr(pattern, arg) && return true
    end
    return false
end
function match_expr(patterns::AbstractArray, ex)
    for pattern in patterns
        match_expr(pattern, ex) && return true
    end
    return false
end

function auto_pattern(ex::Expr)
    if isexpr(ex, :function) || Base.is_short_function_def(ex)
        return _function_name(ex)
    elseif isexpr(ex, :const, 1)
        return auto_pattern(ex.args[1])
    elseif isexpr(ex, :(=))
        return _assignment_name(ex)
    elseif isexpr(ex, :import)
        arg1 = ex.args[1]
        if isexpr(arg1, :(:))
            return map(_import_name, arg1.args[2:end])
        else
            return map(_import_name, ex.args)
        end
    elseif isexpr(ex, :using, 1) && isexpr(ex.args[1], :(:))
        return map(_import_name, ex.args[1].args[2:end])
    else
        return :* # * is wildcard which donate any symbol
    end
end

function _function_name(ex)
    if isexpr(ex, [:function, :(=), :where])
        return _function_name(ex.args[1])
    else # isexpr(ex, :call)
        return ex.args[1]
    end
end

function _assignment_name(ex)
    lhs = ex.args[1]
    lhs isa Symbol && return lhs
    if length(lhs.args) == 1 && isexpr(lhs.args[1], :parameters)
        return lhs.args[1].args
    else
        return lhs.args
    end
end

# for A.B.C the args[end] is C;
# for A.B as C the args[end] is C;
_import_name(ex::Expr) = ex.args[end]::Symbol

const STARTUPS = []

function check_startup(ex)
    isempty(STARTUPS) && return ex
    startup_block = Expr(:block)
    for s in STARTUPS
        if should_eval(ex, s)
            push!(startup_block.args, s.ex)
            s.evaled = true
        end
    end
    isempty(startup_block.args) || pushfirst!(ex.args, startup_block)
    return ex
end

"""
    @lazy_startup ex patterns...

Make given expression `ex` don't evaluate until the `patterns` are matched.
The `patterns` are used to determine when to evaluate the expression.
If `patterns` is not given, the pattern will be determined automatically:
for a function definition, it will be the function name;
for an assignment, it will be the variable name;
for others, it will `*`, where symbol `*` can be used as a wildcard to match anything.
"""
macro lazy_startup(ex, ps...)
    if isempty(ps)
        pattern = auto_pattern(ex)
    else
        pattern = collect(ps)
    end
    startup = Startup(ex, pattern)
    push!(STARTUPS, startup)
    return startup
end

function __init__()
    push!(REPL.repl_ast_transforms, check_startup)
end

end # module
