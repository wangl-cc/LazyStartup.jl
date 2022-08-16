# LazyStartup.jl

[![Build Status](https://github.com/wangl-cc/LazyStartup.jl/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/wangl-cc/LazyStartup.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/wangl-cc/LazyStartup.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/wangl-cc/LazyStartup.jl)
[![GitHub](https://img.shields.io/github/license/wangl-cc/LazyStartup.jl)](https://github.com/wangl-cc/LazyStartup.jl/blob/master/LICENSE)

A simple package provides a way to delay the execution of startup code until it is needed by REPL.
It might be useful if loading `startup.jl` will take a long time.

## Usage

For a `startup.jl` file like this:
```julia
using Revise

function f()
    # do something
end
```
This code will be executed before start the REPL,
and can be delayed by `@lazy_startup`:
```julia
using LazyStartup # NOTE: this package must be loaded in startup.jl

@lazy_startup using Revise import * using * include(*)

@lazy_startup function f()
    # do something
end
```
The first argument of `@lazy_startup` is the expression to be evaluated,
and rest of the arguments are patterns to match expressions input in the REPL,
where `*` is a wildcard to match anything;
if pattern is not provided, it will be generated automatically
(rules for generating patterns see below).
Here, the expression `using Revise` will be evaluated
when `import`, `using` any module or `include` any file;
and the expression `function f() ...` will be evaluated when it's used.
```julia
julia> isdefined(Main, :Revise)
false

julia> using Test

julia> isdefined(Main, :Revise)
true

julia> isdefined(Main, :f)
false

julia> f()

julia> isdefined(Main, :f)
true
```

**Limitation**: Using this package may increase startup time by about 0.1-0.5 seconds (compile time).
Therefore this package is only recommended for code that significantly affects startup time,
such as loading packages.

## Define Pattern

There are some examples for how to define patterns:
```julia
using LazyStartup

# match import, using, and function call
@lazy_startup using Revise import * using * include(*)
# match symbol
@lazy_startup begin
  const FOO = 1
  foo(::Any) = FOO + 1
end foo
# match function call, the brackets are required
# without brackets, the pattern will be a symbol
@lazy_startup begin
  bar(::Any) = 1
  bar(::Int) = 2
end bar()
# match macro call, the brackets are optional for single pattern
# but required for multiple patterns
@lazy_startup using Test @test
@lazy_startup using BenchmarkTools @btime() @benchmark()
```

**NOTE**: The pattern matching is not sensitive for order and number of arguments.
Thus, `bar()` will match `bar()`, `bar(x)`, `bar(x, y)`, and with more arguments.
Similarly, `@test` will match `@test`, `@test x`, `@test x y`, and with more arguments.

## Default Pattern

If pattern is not provided, patterns will be generated automatically.

| Expression | Pattern |
| :--------- | :------ |
| Declare variable: `v = 1` or `const v = 1` | Variable name `v` |
| Function definition: `f() = 1` or `function f(); end` | Function name `f` |
| macro definition: `macro f(); end` | Macro name `@f` |
| Import modules: `import A` | Module name `A` |
| Import submodule: `import A.B` | Submodule name `B` |
| Import function: `import A.f` | Function name `f` |
| Import and rename module: `import A as B` | Renamed module name `B` |
| Import and rename function: `import A.f as g` or `import A: f as g` | Renamed function name `g` |
| Others | A wildcard `*`|

For other expressions, the pattern wildcard `*` will match anything,
which means that the expression will evaluate after any input in the REPL.
To avoid confusion, those expressions will show an info message,
which can be silenced by set environment variable `JULIA_LAZY_STARTUP_SILENT` to `true`.
