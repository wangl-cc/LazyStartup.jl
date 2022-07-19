using Test
using LazyStartup
using LazyStartup: match_expr, auto_pattern, check_startup, STARTUPS
using Base.Meta: isexpr

macro test_auto_pattern(p, ex)
    auto_p = auto_pattern(ex)
    if isexpr(p, :vect)
        return :(@test $(p.args == auto_p))
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
        @test_auto_pattern x x = 1
        @test_auto_pattern [y, z] (y, z) = (1, 1)
        @test_auto_pattern [a, b] (; a, b) = (; a=1, b=2, c=3)
        @test_auto_pattern x const x = 1
        @test_auto_pattern [y, z] const (y, z) = (1, 1)
        @test :* == auto_pattern(:())
    end

    @testset "check_startup" begin
        @lazy_startup f() = 1
        @lazy_startup const A = 1
        @lazy_startup using Revise using * include
        @lazy_startup begin
            g(::Int) = 1
            g(::Real) = 1.0
        end g
        is_evaled(s) = s.evaled
        @test check_startup(Expr(:toplevel, :x)).args[1] == :x
        @test all(!is_evaled, STARTUPS)
        @test check_startup(Expr(:toplevel, :f)).args[1].args[1] == STARTUPS[1].ex
        @test is_evaled(STARTUPS[1])
        @test all(!is_evaled, STARTUPS[2:end])
        @test check_startup(Expr(:toplevel, :A)).args[1].args[1] == STARTUPS[2].ex
        @test is_evaled(STARTUPS[2])
        @test all(!is_evaled, STARTUPS[3:end])
        @test check_startup(Expr(:toplevel, :(using Test))).args[1].args[1] == STARTUPS[3].ex
        @test is_evaled(STARTUPS[3])
        @test all(!is_evaled, STARTUPS[4:end])
        @test check_startup(Expr(:toplevel, :g)).args[1].args[1] == STARTUPS[4].ex
        @test is_evaled(STARTUPS[4])
        @test all(!is_evaled, STARTUPS[5:end])
    end
end
