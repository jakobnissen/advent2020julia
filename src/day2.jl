import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

machine = let
    letter = re"[a-z]"
    number = re"[0-9]+"
    range = number * re"-" * number
    singleletter = letter * re""
    letters = re.rep1(letter)
    newline = re"\r?\n"
    line = range * re" " * singleletter * re":" * re" " * letters

    singleletter.actions[:enter] = [:enter_letter]
    letters.actions[:enter] = [:enter_letters]
    letters.actions[:all] = [:all_letters]
    letters.actions[:exit] = [:exit_letters]
    number.actions[:all] = [:all_number]
    number.actions[:exit] = [:exit_number]

    Automa.compile(line * re.rep(newline * line) * re.opt(newline))
end

actions1 = Dict(
    :enter_letter => :(letter = byte),
    :enter_letters => quote nothing end,
    :all_letters => :(count += letter == byte),
    :exit_letters => quote
        nvalid += (low <= count) & (count <= high)
        low = nothing
        count = 0
    end,
    :all_number => :(n = n * UInt32(10) + (byte - UInt8(0x30))),
    :exit_number => quote
        if low === nothing
            low = n
        else
            high = n
            if high < low
                error("Right number in range must not be lower than left")
            end
        end
        n = zero(UInt32)
    end,
)

actions2 = Dict(actions1...,
    :enter_letters => :(lettermark = p % UInt),
    :all_letters => quote nothing end,
    :exit_letters => quote
        len = p - lettermark + 1
        len < max(low, high) && error("String of letters at byte $lettermark too short")
        letlow = @inbounds data[lettermark + low % UInt - UInt(1)] == letter
        lethigh = @inbounds data[lettermark + high % UInt - UInt(1)] == letter
        nvalid += letlow ⊻ lethigh
        low = nothing
    end,
    :exit_number => quote
        low === nothing ? (low = n) : (high = n)
        n = zero(UInt32)
    end,
)

vars = Automa.Variables(:p, :p_end, :p_eof, :ts, :te, :cs, :data, :mem, :byte)
context = Automa.CodeGenContext(vars=vars, generator=:goto, checkbounds=false, loopunroll=4)

for part in 1:2
    @eval function $(Symbol("part", part))(data::Union{SubString{String}, String, Vector{UInt8}})
        low = nothing
        nvalid = 0
        letter = zero(UInt8)
        high = n = zero(UInt32)
        $([:count, :lettermark][part]) = 0

        $(Automa.generate_init_code(context, machine))
        p_end = p_eof = sizeof(data)
        $(Automa.generate_exec_code(context, machine, [actions1, actions2][part]))

        iszero(cs) || error("Parser error: Invalid byte at: ", p)
        return nvalid
    end
end

function day2(io::IO, path)
    data = open(read, path)
    println(io, "Solution day2 part1: ", part1(data))
    println(io, "Solution day2 part2: ", part2(data))
end
