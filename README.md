# LazyStartup.jl

A simple package provides a way to delay the execution of startup code until it is needed by REPL.
It might be useful if loading `startup.jl` will take a long time.

## Usage

For a `startup.jl` file like this:
```julia
using Revise

const C = 1

function f()
    # do something
end
```
This code will be executed before start the REPL,
and can be delayed by `@lazy_startup`:
```julia
using LazyStartup # NOTE: this package must be loaded in startup.jl

@lazy_startup using Revise import * using * include(*)

@lazy_startup const C = 1

@lazy_startup function f()
    ...
end
```
Here, the expression `using Revise` will be evaluated
when `import`, `using` any module or `include` any file is called;
and the expression `const C = 1`, and the expression `function f()` will be evaluated when it's used.
```julia
julia> isdefined(Main, :Revise)
false

julia> using Test

julia> isdefined(Main, :Revise)
true

julia> isdefined(Main, :C)
false

julia> C
1

julia> isdefined(Main, :C)
true

julia> isdefined(Main, :f)
false

julia> f()

julia> isdefined(Main, :f)
true
```

The first argument of `@lazy_startup` is the expression to be evaluated,
and rest of the arguments are patterns to match expressions input in the REPL,
where `*` is a wildcard to match anything;
for variable or function definition,
if pattern is not provided, it will be the name of the variable or function, (e.g. `C` and `f` in above example).
