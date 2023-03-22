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
    # test current expression
    ex_match = false
    if pattern.head === ex.head
        ex_match = true
        for sub_p in pattern.args
            sub_p isa LineNumberNode && continue
            arg_match = false
            for arg in ex.args
                arg isa LineNumberNode && continue
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
    # test sub expressions of ex
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
    elseif isexpr(ex, :macro)
        return Symbol("@$(_function_name(ex))")
    else
        if !parse(Bool, get(ENV, "JULIA_LAZY_STARTUP_SILENT", "false"))
            @info """
            can't determine pattern automatically for expression: $ex;
            it will be evaluated after any input in the REPL;
            if you want to silence this info, set environment variable JULIA_LAZY_STARTUP_SILENT to true
            """
        end
        return :* # * is wildcard which donate any symbol
    end
end

function _function_name(ex)
    if isexpr(ex, [:function, :macro, :(=), :where])
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
    startup_block = Expr(:toplevel)
    for s in STARTUPS
        if should_eval(ex, s)
            push!(startup_block.args, s.ex)
            s.evaled = true
        end
    end
    isempty(startup_block.args) && return ex
    push!(startup_block.args, ex)
    return startup_block
end

function collect_pattern(ps)
    ret = Vector{Any}(undef, length(ps))
    for i in eachindex(ps)
        ret[i] = _maybe_to_symbol(ps[i])
    end
    return ret
end

function _maybe_to_symbol(@nospecialize ex)
    if isexpr(ex, :call, 2) && ex.args[1] === :Symbol && ex.args[2] isa String
        return Symbol(ex.args[2])
    else
        return ex
    end
end

"""
    @lazy_startup ex patterns...

Delay the execution of the given expression `ex` until inputs in REPL match `patterns`.
If the given pattern is a macro like `@btime`, the pattern should be `Symbol("@btime")`.
If `patterns` is not given, the pattern will be determined automatically.
Details of default pattern, see README.md.
"""
macro lazy_startup(ex, ps...)
    if isempty(ps)
        pattern = auto_pattern(ex)
    else
        pattern = collect_pattern(ps)
    end
    startup = Startup(ex, pattern)
    push!(STARTUPS, startup)
    return startup
end

function __init__()
    push!(REPL.repl_ast_transforms, check_startup)
end

end # module
