using Test
using LazyStartup
using LazyStartup: match_expr, auto_pattern, check_startup, STARTUPS
using Base.Meta: isexpr

macro test_auto_pattern(p, ex)
    auto_p = auto_pattern(ex)
    if isexpr(p, :vect)
        return :(@test $(p.args == auto_p))
    elseif isexpr(p, :call, 2) && p.args[1] === :Symbol && p.args[2] isa String
        return :(@test $(Symbol(p.args[2]) == auto_p))
    else
        return :(@test $(p == auto_p))
    end
end

@testset "LazyStartup" begin
    @testset "match_expr" begin
        @test match_expr(:*, :x)
        @test match_expr(:*, :(x + y))
        @test match_expr(:x, :x)
        @test match_expr(:x, :(x + y))
        @test match_expr(:y, :(f(x) + g(y)))
        @test match_expr(:g, :(f(x) + g(y)))
        @test !match_expr(:x, :y)
        @test !match_expr(:x, :(g(y)))
        @test !match_expr(:f, :(g(y)))
        @test match_expr(:(using *), :(using Test))
        @test match_expr(:(using *), :(using Test, LazyStartup))
        @test match_expr(:(using *), quote
            using Test
            x + 1
        end)
        @test match_expr([:(using *), :(include(*))], :(using Test))
        @test match_expr([:(using *), :(include(*))], :(include("runtests.jl")))
        @test !match_expr([:(using *), :(include(*))], :(x + 1))
        @test !match_expr(:(using Test), :(using LazyStartup))
    end

    @testset "auto_pattern" begin
        @test_auto_pattern f f() = 1
        @test_auto_pattern f function f(); 1; end
        @test_auto_pattern Symbol("@foo") macro foo() end
        @test_auto_pattern x x = 1
        @test_auto_pattern [y, z] (y, z) = (1, 1)
        @test_auto_pattern [a, b] (; a, b) = (; a=1, b=2, c=3)
        @test_auto_pattern x const x = 1
        @test_auto_pattern [y, z] const (y, z) = (1, 1)
        @test_auto_pattern [A] import A
        @test_auto_pattern [B] import A.B
        @test_auto_pattern [f] import A.f
        @test_auto_pattern [f] import A: f
        @test_auto_pattern [f] import A: f
        @test_auto_pattern [f, g] import A: f, g
        @test_auto_pattern [f, g] using A: f, g
        @static if VERSION >= v"1.6"
            # import A as B is supported after julia v1.6
            @test_auto_pattern [B] import A as B
            @test_auto_pattern [C] import A.B as C
            @test_auto_pattern [g] import A.f as g
            @test_auto_pattern [f1, g1] import A: f as f1, g as g1
            @test_auto_pattern [f1, g1] using A: f as f1, g as g1
        end
        @test :* == auto_pattern(:(using A))
        @test :* == auto_pattern(:())
    end

    @testset "check_startup" begin
        @lazy_startup f() = 1
        @lazy_startup const A = 1
        @lazy_startup using Revise using * include(*)
        @lazy_startup begin
            g(::Int) = 1
            g(::Real) = 1.0
        end g
        @lazy_startup import Foo
        @lazy_startup import Foo: h
        # issue #4
        @lazy_startup using BenchmarkTools Symbol("@btime")
        @lazy_startup using Unitful @u_str
        @lazy_startup macro showall(expr)
            return quote
                show(IOContext(stdout, :compact => false, :limit => false), "text/plain", $(esc(expr)))
            end
        end
        @static if VERSION >= v"1.6"
            @lazy_startup import Foo as Bar
            @lazy_startup import Foo: h as h1
        end
        is_evaled(s) = s.evaled
        @test check_startup(Expr(:toplevel, :x)).args[1] == :x
        @test all(!is_evaled, STARTUPS)
        test_exprs = [
            :f, :A, :(using Test), :g, :Foo, :h, :(@btime 1), :(u"bohr"), :(@showall 1)
        ]
        @static if VERSION >= v"1.6"
            push!(test_exprs, :Bar, :h1)
        end
        @test length(STARTUPS) == length(test_exprs)
        for expr in test_exprs
            @test check_startup(Expr(:toplevel, expr)).args[1].args[1] == STARTUPS[1].ex
            @test is_evaled(STARTUPS[1])
            popfirst!(STARTUPS)
            @test all(!is_evaled, STARTUPS)
        end
    end
end
