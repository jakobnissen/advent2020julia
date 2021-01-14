using Transducers

function getfirst(proc::Transducers.Eduction)
    y = iterate(proc)
    y === nothing && return nothing
    return first(y)
end
getfirst(::Nothing) = nothing

function remaining(v::AbstractVector{<:Unsigned}, nums, target)
    # Exit conditions where no solutions are possible
    target < 0 && return nothing
    length(v) < nums && return nothing

    # If only one num, this is a simple loop
    isone(nums) && return first(v |> Filter(isequal(target)))

    # Else we iterate over all n - 1
    firstindex(v):lastindex(v) - nums + 1 |>
        Map(i -> (v[i], remaining(view(v, i+1:lastindex(v)), nums - 1, target - v[i]))) |>
        NotA(Tuple{Any, Nothing}) |>
        first |> 
        x -> x === nothing ? nothing : prod(x))
end    

function day1()
    numbers = open("data/day1.txt") do file
        eachline(file) |> Map(rstrip) |> Filter(!isempty) |>
        Map(line -> parse(UInt, line)) |> collect
    end
    println("Day 1 part 1: ", Int(remaining(numbers, 2, 2020)))
    println("Day 1 part 2: ", Int(remaining(numbers, 3, 2020)))
end
