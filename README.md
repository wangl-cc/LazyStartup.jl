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
when `import`, `using` any module or `include` any file is called;
and the expression `function f()` will be evaluated when it's used.
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

## Default Pattern

Patterns are generated automatically if not provided.

| Expression | Pattern |
| :--------- | :------ |
| Declare variable: `v = 1` or `const v = 1` | Variable name `v` |
| Function definition: `f() = 1` or `function f(); end` | Function name `f` |
| Import modules: `import A` | Module name `A` |
| Import submodule: `import A.B` | Submodule name `B` |
| Import function: `import A.f` | Function name `f` |
| Import and rename module: `import A as B` | Renamed module name `B` |
| Import and rename function: `import A.f as g` or `import A: f as g` | Renamed function name `g` |
| Others | A wildcard `*`|
